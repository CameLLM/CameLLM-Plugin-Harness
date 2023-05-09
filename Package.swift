// swift-tools-version: 5.7

import PackageDescription

let package = Package(
  name: "CameLLMPluginHarness",
  platforms: [
    .macOS(.v10_15),
    .iOS(.v13),
  ],
  products: [
    .library(
      name: "CameLLMPluginHarness",
      targets: ["CameLLMPluginHarness"]),
    .library(
      name: "CameLLMPluginHarnessObjCxx",
      targets: ["CameLLMPluginHarnessObjCxx"]),
  ],
  dependencies: [
    .package(url: "https://github.com/CameLLM/CameLLM.git", branch: "main"),
    .package(url: "https://github.com/alexrozanski/Coquille.git", from: "0.3.0")
  ],
  targets: [
    .target(
      name: "CameLLMPluginHarness",
      dependencies: ["CameLLM", "Coquille"]),
    .target(
      name: "CameLLMPluginHarnessObjCxx",
      dependencies: [
        .product(name: "CameLLMObjCxx", package: "CameLLM")
      ]
    )
  ]
)
