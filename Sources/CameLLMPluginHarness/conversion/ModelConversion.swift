//
//  ModelConversion.swift
//
//
//  Created by Alex Rozanski on 08/04/2023.
//

import Foundation
import CameLLM

public protocol ModelConversion<
  DataType,
  ValidatedDataType,
  ConversionStep,
  ValidationError,
  ResultType
> where DataType: ModelConversionData<ValidationError>, ValidationError: Error {
  associatedtype DataType // Input data type
  associatedtype ValidatedDataType // Data type returned from validation (may be the same as DataType)
  associatedtype ConversionStep // The conversion step type. Probably an enum
  associatedtype ConversionPipelineInputType // The input type to the conversion pipeline. This should probably contain ValidatedDataType
  associatedtype ValidationError // The Error type for errors returned from validation
  associatedtype ResultType // The result type from the conversion operation

  // Steps
  static var conversionSteps: [ConversionStep] { get }

  // Validation
  static func validate(
    _ data: DataType,
    returning outRequiredFiles: inout [ModelConversionFile]?
  ) -> Result<ValidatedModelConversionData<ValidatedDataType>, ValidationError>

  // Pipeline
  func makeConversionPipeline() -> ModelConversionPipeline<ConversionStep, ConversionPipelineInputType, ResultType>
}
