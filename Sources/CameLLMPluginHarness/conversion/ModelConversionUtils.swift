//
//  ModelConversionUtils.swift
//
//
//  Created by Alex Rozanski on 09/04/2023.
//

import Foundation
import Combine
import Coquille
import CameLLM

struct PythonScriptFile {
  let name: String
  let `extension` = "py"

  var filename: String {
    return "\(name).\(`extension`)"
  }
}

public class PythonScript {
  public let url: URL
  public let pythonDependencies: [String]
  public let dependentScripts: [PythonScript]

  var filename: String {
    return url.lastPathComponent
  }

  public init(
    url: URL,
    pythonDependencies: [String] = [],
    dependentScripts: [PythonScript] = []
  ) {
    self.url = url
    self.pythonDependencies = pythonDependencies
    self.dependentScripts = dependentScripts
  }
}

public class ModelConversionUtils {
  public static let shared = ModelConversionUtils()

  private init() {}

  // MARK: ModelConversionStep Builders

  public func makeCheckEnvironmentStep<ConversionStep, InputType>(stepType: ConversionStep) -> ModelConversionStep<
    ConversionStep,
    InputType,
    InputType
  > {
    return ModelConversionStep(type: stepType, executionHandler: { input, command, stdout, stderr, cancel in
      return try await self.checkConversionEnvironment(
        input: input,
        connectors: CommandConnectors(command: command, stdout: stdout, stderr: stderr, cancel: cancel)
      )
    }, cleanUpHandler: { _ in return true })
  }

  public func makeInstallPythonDependenciesStep<ConversionStep, InputType>(
    stepType: ConversionStep,
    dependencies: [String]
  ) -> ModelConversionStep<
    ConversionStep,
    InputType,
    InputType
  > {
    return ModelConversionStep(type: stepType, executionHandler: { input, command, stdout, stderr, cancel in
      return try await self.installPythonDependencies(
        input: input,
        dependencies: dependencies,
        connectors: CommandConnectors(command: command, stdout: stdout, stderr: stderr, cancel: cancel)
      )
    }, cleanUpHandler: { _ in return true })
  }

  public func makeCheckInstalledPythonDependenciesStep<ConversionStep, InputType>(
    stepType: ConversionStep,
    dependencies: [String]
  ) -> ModelConversionStep<
    ConversionStep,
    InputType,
    InputType
  > {
    return ModelConversionStep(type: stepType, executionHandler: { input, command, stdout, stderr, cancel in
      return try await self.checkInstalledPythonDependencies(
        input: input,
        dependencies: dependencies,
        connectors: CommandConnectors(command: command, stdout: stdout, stderr: stderr, cancel: cancel)
      )
    }, cleanUpHandler: { _ in return true })
  }

  // MARK: - Validation Utils

  public func modelConversionFiles(
    from fileURLs: [URL]
  ) -> [ModelConversionFile] {
    return fileURLs.map { fileURL in
      ModelConversionFile(url: fileURL, found: FileManager.default.fileExists(atPath: fileURL.path))
    }
  }

  // MARK: - Conversion Utils

  public func checkConversionEnvironment<Input>(
    input: Input,
    connectors: CommandConnectors
  ) async throws -> ModelConversionStatus<Input> {
    let status = try await run(Coquille.Process.Command("which", arguments: ["python3"]), commandConnectors: connectors)
    switch status {
    case .success:
      return .success(result: input)
    case .failure(exitCode: let exitCode):
      return .failure(exitCode: exitCode)
    case .cancelled:
      return .cancelled
    }
  }

  public func installPythonDependencies<Input>(
    input: Input,
    dependencies: [String],
    connectors: CommandConnectors
  ) async throws -> ModelConversionStatus<Input> {
    let status = try await run(Coquille.Process.Command("python3", arguments: ["-u", "-m", "pip", "install"] + dependencies), commandConnectors: connectors)
    switch status {
    case .success:
      return .success(result: input)
    case .failure(exitCode: let exitCode):
      return .failure(exitCode: exitCode)
    case .cancelled:
      return .cancelled
    }
  }

  public func checkInstalledPythonDependencies<Input>(
    input: Input,
    dependencies: [String],
    connectors: CommandConnectors
  ) async throws -> ModelConversionStatus<Input> {
    for dependency in dependencies {
      if connectors.cancel.value {
        return .cancelled
      }

      let status = try await run(Coquille.Process.Command("python3", arguments: ["-u", "-m", "pip", "show", dependency]), commandConnectors: connectors)
      switch status {
      case .success:
        break
      case .failure(exitCode: let exitCode):
        return .failure(exitCode: exitCode)
      case .cancelled:
        return .cancelled
      }
    }
    return .success(result: input)
  }

  public func runPythonScript(
    _ script: PythonScript,
    arguments: [String],
    commandConnectors: CommandConnectors
  ) async throws -> ModelConversionStatus<Void> {
    let temporaryDirectoryURL: URL
    if #available(macOS 13.0, iOS 16.0, *) {
      temporaryDirectoryURL = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
    } else {
      temporaryDirectoryURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    }
    try FileManager.default.createDirectory(at: temporaryDirectoryURL, withIntermediateDirectories: true)

    // TODO: handle recursive dependencies here if they are needed.
    let allScripts = [script] + script.dependentScripts
    var scriptFileURLs: [URL] = []
    for script in allScripts {
      let status = try writeScript(script, to: temporaryDirectoryURL)
      guard let scriptFileURL = status.result else {
        return .failure(exitCode: 1)
      }
      scriptFileURLs.append(scriptFileURL)
    }

    guard scriptFileURLs.count == allScripts.count, let mainScriptFileURL = scriptFileURLs.first else {
      return .failure(exitCode: 1)
    }

    return try await run(
      Coquille.Process.Command(
        "python3",
        arguments: [
          "-u",
          mainScriptFileURL.path
        ] + arguments
      ),
      commandConnectors: commandConnectors
    )
  }

  private func writeScript(_ script: PythonScript, to scriptDirectoryURL: URL) throws -> ModelConversionStatus<URL> {
    let scriptFileURL: URL
    if #available(macOS 13.0, iOS 16.0, *) {
      scriptFileURL = scriptDirectoryURL.appending(path: script.filename, directoryHint: .notDirectory)
    } else {
      scriptFileURL = scriptDirectoryURL.appendingPathComponent(script.filename, isDirectory: false)
    }

    let contents = try String(contentsOf: script.url)
    try contents.write(to: scriptFileURL, atomically: true, encoding: .utf8)

    return .success(result: scriptFileURL)
  }

  // MARK: - Running Commands

  public func run(_ command: Coquille.Process.Command, commandConnectors: CommandConnectors) async throws -> ModelConversionStatus<Void> {
    return try await withCheckedThrowingContinuation { continuation in
      commandConnectors.command?([[command.name], command.arguments].flatMap { $0 }.joined(separator: " "))

      var cancellable: AnyCancellable?
      let process = Process(command: command, stdout: commandConnectors.stdout, stderr: commandConnectors.stderr)
      let processCancellable = process.run { status in
        withExtendedLifetime(cancellable) {
          continuation.resume(returning: status.toModelConversionStatus())
        }
      }

      cancellable = commandConnectors.cancel.sink { isCancelled in
        if isCancelled {
          processCancellable.cancel()
        }
      }
    }
  }
}

fileprivate extension Coquille.Process.Status {
  func toModelConversionStatus() -> ModelConversionStatus<Void> {
    switch self {
    case .success:
      return .success(result: ())
    case .failure(let code):
      return .failure(exitCode: code)
    }
  }
}
