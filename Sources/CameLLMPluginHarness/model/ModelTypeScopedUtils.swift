//
//  ModelTypeScopedUtils.swift
//
//
//  Created by Alex Rozanski on 22/04/2023.
//

import Foundation
import CameLLM

public protocol ModelTypeScopedCardUtils {
  associatedtype CardType

  func getModelCard(forFileAt fileURL: URL) throws -> CardType?
}

public protocol ModelTypeScopedValidationUtils {
  func validateModel(at fileURL: URL) throws
}
