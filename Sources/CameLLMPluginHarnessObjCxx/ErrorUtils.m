//
//  ErrorUtils.m
//
//
//  Created by Alex Rozanski on 22/04/2023.
//

#import <Foundation/Foundation.h>
#import "ErrorUtils.h"

NSError *makeError(NSString *domain, NSUInteger errorCode, NSString *description, NSError *underlyingError)
{
  NSMutableDictionary *userInfo = [[NSMutableDictionary alloc] init];
  if (description != nil) {
    userInfo[NSLocalizedDescriptionKey] = description;
  }

  if (underlyingError != nil) {
    userInfo[NSUnderlyingErrorKey] = underlyingError;
  }

  return [[NSError alloc] initWithDomain:domain code:errorCode userInfo:userInfo];
}

NSError *makeCameLLMError(_CameLLMErrorCode errorCode, NSString *description)
{
  return makeCameLLMErrorWithUnderlyingError(errorCode, description, nil);
}

NSError *makeCameLLMErrorWithUnderlyingError(_CameLLMErrorCode errorCode, NSString *description, NSError *underlyingError)
{
  return makeError(_CameLLMErrorDomain, errorCode, description, underlyingError);
}

NSError *makeFailedToLoadModelErrorWithUnderlyingError(NSError *underlyingError)
{
  return makeCameLLMErrorWithUnderlyingError(_CameLLMErrorCodeFailedToLoadModel, @"Failed to load model", underlyingError);
}

NSError *makeFailedToPredictErrorWithUnderlyingError(NSError *underlyingError)
{
  return makeCameLLMErrorWithUnderlyingError(_CameLLMErrorCodeFailedToPredict, @"Failed to run prediction", underlyingError);
}
