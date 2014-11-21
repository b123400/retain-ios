//
//  RetainCC.h
//  retaincc
//
//  Created by b123400 on 22/9/14.
//  Copyright (c) 2014 oursky. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 * The main class of RetainCC
 *
 * This is the only class developers have to use.
 */
@interface RetainCC : NSObject

/** @name Setting up */

/**
 * Create a shared instance with Api key and app ID.
 *
 * This method has to be called once before calling -shared
 * If this method is called more than once, it will change the Api key and app ID, but not creating new instance.
 * 
 * @param apiKey The Api you get from RetainCC website.
 * @param appID The app ID you get from RetainCC website.
 * @return A shared instance of RetainCC.
 */
+ (instancetype)sharedInstanceWithApiKey:(NSString*)apiKey appID:(NSString*)appID;
/**
 * Access the shared instance.
 *
 * Once you have called -sharedInstanceWithApiKey:appID:, you can access the shared instance by this method.
 * @return A shared instance of RetainCC.
 */
+ (instancetype)shared;

/**
 * Create a instance with Api key and app ID.
 *
 * This method create an instance, not shared but a normal instance.
 * You can create multiple RetainCC instance for the same application using this method.
 * You will have to manage the instance yourself.
 *
 * @param apiKey The Api you get from RetainCC website.
 * @param appID The app ID you get from RetainCC website.
 * @return An instance of RetainCC.
 */
- (instancetype)initWithApiKey:(NSString*)apiKey appID:(NSString*)appID;

/** @name Logging */

/**
 * Log event.
 *
 * @param name The name of the event. For example: openedProfile
 * @param dict Extra information of the event. RetainCC uses NSJSONSerialization under the hood, so the provided objects have to be a valid JSON object, such as NSArray, NSDictionary, NSString and NSNumber. Providing custom objects will gives error.
 */
- (void)logEventWithName:(NSString*)name properties:(NSDictionary*)dict;

/**
 * Tell RetainCC the identity of the current user.
 *
 * Every instance of RetainCC can only have one user at a time.
 *
 * @param userID The user ID of the current user, can be nil.
 * @param email The email if the current user, can be nil.
 *
 * If both of userID and email are nil, it will be treated as logged out.
 */
- (void)identifyWithEmail:(NSString*)email userID:(NSString*)userID;

/**
 * Changing user attributes.
 *
 * @param dictionary Attributes of the current user, can be anything such as Name, Age, Company or whatever you like. This object will be serialized using NSJSONSerialization, so it have to be a valid JSON object, such as NSDictionary, NSArray, NSString, NSNumber. Providing custom objects will gives error.
 */
- (void)changeUserAttributes:(NSDictionary*)dictionary;

/**
 * Inform RetainCC when you got the push token, you can call this multiple times.
 *
 * @param pushToken The data iOS returned when user gives you permission.
 */

- (void)setDevicePushToken:(NSData*)pushToken;

@end
