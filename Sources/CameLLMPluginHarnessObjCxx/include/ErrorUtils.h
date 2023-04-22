//
//  ErrorUtils.h
//
//
//  Created by Alex Rozanski on 22/04/2023.
//

#import <Foundation/Foundation.h>

#import "CameLLMError.h"

#ifdef  __cplusplus
extern "C" {
#endif

NS_ASSUME_NONNULL_BEGIN

NSError *makeError(NSString *domain, NSUInteger errorCode, NSString *description, NSError *__nullable underlyingError);

NSError *makeCameLLMError(_CameLLMErrorCode errorCode, NSString *description);
NSError *makeCameLLMErrorWithUnderlyingError(_CameLLMErrorCode errorCode, NSString *description, NSError *__nullable underlyingError);

NSError *makeFailedToLoadModelErrorWithUnderlyingError(NSError *__nullable underlyingError);
NSError *makeFailedToPredictErrorWithUnderlyingError(NSError *__nullable underlyingError);

NS_ASSUME_NONNULL_END

#ifdef  __cplusplus
}
#endif
