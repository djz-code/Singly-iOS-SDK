//
//  SinglySession.m
//  SinglySDK
//
//  Copyright (c) 2012-2013 Singly, Inc. All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions are met:
//
//  * Redistributions of source code must retain the above copyright notice,
//    this list of conditions and the following disclaimer.
//
//  * Redistributions in binary form must reproduce the above copyright notice,
//    this list of conditions and the following disclaimer in the documentation
//    and/or other materials provided with the distribution.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
//  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
//  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
//  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
//  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
//  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
//  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
//  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
//  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
//  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
//  POSSIBILITY OF SUCH DAMAGE.
//

#import <AddressBook/AddressBook.h>
#import <AddressBookUI/AddressBookUI.h>

#import "NSURL+AccessToken.h"

#import "SinglyAlertView.h"
#import "SinglyConnection.h"
#import "SinglyConstants.h"
#import "SinglyFacebookService.h"
#import "SinglyKeychainItemWrapper.h"
#import "SinglyLog.h"
#import "SinglyRequest.h"
#import "SinglySession.h"
#import "SinglySession+Internal.h"

static SinglySession *sharedInstance = nil;

@implementation SinglySession

+ (SinglySession *)sharedSession
{
    static dispatch_once_t queue;
    dispatch_once(&queue, ^{
        sharedInstance = [[SinglySession alloc] init];
    });

    return sharedInstance;
}

+ (SinglySession *)sharedSessionInstance
{
    return sharedInstance;
}

- (id)init
{
    self = [super init];
    if (self)
    {
        _accessTokenWrapper = [[SinglyKeychainItemWrapper alloc] initWithIdentifier:kSinglyAccessTokenKey accessGroup:nil];
        _baseURL = kSinglyBaseURL;
    }
    return self;
}

#pragma mark - Session Configuration

- (NSString *)accountID
{
    NSString *theAccountID = [self.accessTokenWrapper objectForKey:(__bridge id)kSecAttrAccount];
    if (theAccountID.length == 0) theAccountID = nil;
    return theAccountID;
}

- (void)setAccountID:(NSString *)accountID
{
    [self.accessTokenWrapper setObject:accountID forKey:(__bridge id)kSecAttrAccount];
}

- (NSString *)accessToken
{
    NSString *theAccessToken = [self.accessTokenWrapper objectForKey:(__bridge id)kSecValueData];
    if (theAccessToken.length == 0) theAccessToken = nil;
    return theAccessToken;
}

- (void)setAccessToken:(NSString *)accessToken
{
    [self.accessTokenWrapper setObject:accessToken forKey:(__bridge id)kSecValueData];
}

#pragma mark - Session Management

- (BOOL)isReady
{
    BOOL ready = YES;

    // The access token and account id should be set...
    if (!self.accessToken) ready = NO;
    if (!self.accountID) ready = NO;

    // The loaded profile id should match the account id...
    if (self.profile && ![self.profile[@"id"] isEqualToString:self.accountID])
        ready = NO;

    return ready;
}

- (BOOL)startSession:(NSError **)error
{
    // Raise an error if the Client ID and Client Secret have not been provided!
    if (!self.clientID || !self.clientSecret)
        [NSException raise:kSinglyCredentialsMissingException
                    format:@"%s: missing client id and/or client secret!", __PRETTY_FUNCTION__];

    // Ensure that we have an Access Token and Account ID...
    if (!self.accountID || !self.accessToken)
        return NO;

    // Update Profiles
    NSError *updateProfilesError;
    BOOL isSuccessful = [self updateProfiles:&updateProfilesError];

    // Handle Errors
    if (!isSuccessful)
    {
        SinglyLog(@"An error occurred while updating profiles: %@", updateProfilesError);
        if (error) *error = updateProfilesError;
    }

    // Handle Success
    else
    {
        // Post Notification
        [[NSNotificationCenter defaultCenter] postNotificationName:kSinglySessionStartedNotification
                                                            object:nil];
    }

    return isSuccessful;
}

- (void)startSessionWithCompletion:(SinglySessionCompletionBlock)completionHandler
{
    dispatch_queue_t currentQueue = dispatch_get_current_queue();
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{

        // Start the Session
        NSError *sessionStartError;
        BOOL isSuccessful = [self startSession:&sessionStartError];

        // Handle Errors
        if (sessionStartError)
            SinglyLog(@"An error occurred while starting the session: %@", sessionStartError);

        // Call the Completion Handler
        if (completionHandler) dispatch_sync(currentQueue, ^{
            completionHandler(isSuccessful, sessionStartError);
        });

    });
}

- (void)startSessionWithCompletionHandler:(SinglySessionCompletionBlock)completionHandler // DEPRECATED
{
    [self startSessionWithCompletion:completionHandler];
}

- (BOOL)resetSession
{

    // Reset Access Token and Account ID
    self.accessToken = nil;
    self.accountID = nil;

    // Reset the Keychain Item
    [self.accessTokenWrapper resetKeychainItem];

    // Reset Profiles
    [self resetProfiles];

    // Post Notification
    [[NSNotificationCenter defaultCenter] postNotificationName:kSinglySessionResetNotification
                                                        object:nil];

    return YES;

}

- (BOOL)removeAccount:(NSError **)error
{

    // Prepare the Request
    SinglyRequest *request = [SinglyRequest requestWithEndpoint:@"profiles"];
    request.HTTPMethod = @"DELETE";

    // Perform the Request
    NSError *requestError;
    SinglyConnection *connection = [SinglyConnection connectionWithRequest:request];
    [connection performRequest:&requestError];

    // Check for Errors
    if (requestError)
    {
        SinglyLog(@"A request error occurred: %@", requestError.localizedDescription);
        if (error) *error = requestError;
        return NO;
    }

    [self resetSession];

    return YES;

}

- (void)removeAccountWithCompletion:(SinglyRemoveAccountCompletionBlock)completionHandler
{
    dispatch_queue_t currentQueue = dispatch_get_current_queue();
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{

        NSError *error;
        BOOL isSuccessful = [self removeAccount:&error];

        dispatch_sync(currentQueue, ^{
            completionHandler(isSuccessful, error);
        });
        
    });
}

- (void)requestAccessTokenWithCode:(NSString *)code // DEPRECATED
{
    [self requestAccessTokenWithCode:code completion:nil];
}

- (NSString *)requestAccessTokenWithCode:(NSString *)code error:(NSError **)error
{

    // Prepare the Request
    SinglyRequest *request = [SinglyRequest requestWithEndpoint:@"oauth/access_token"];
    request.HTTPMethod = @"POST";
    request.parameters = @{
        @"code" : code,
        @"client_id" : self.clientID,
        @"client_secret" : self.clientSecret
    };

    // Perform the Request
    NSError *requestError;
    SinglyConnection *connection = [SinglyConnection connectionWithRequest:request];
    id responseObject = [connection performRequest:&requestError];

    // Check for Errors
    if (requestError)
    {
        SinglyLog(@"A request error occurred: %@", requestError.localizedDescription);
        if (error) *error = requestError;
        return nil;
    }

    // Persist the Access Token and Account ID
    self.accessToken = responseObject[@"access_token"];
    self.accountID = responseObject[@"account"];

    return self.accessToken;
}

- (void)requestAccessTokenWithCode:(NSString *)code
                        completion:(SinglyAccessTokenCompletionBlock)completionHandler
{
    dispatch_queue_t currentQueue = dispatch_get_current_queue();
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{

        NSError *error;
        NSString *accessToken = [self requestAccessTokenWithCode:code error:&error];

        dispatch_sync(currentQueue, ^{
            completionHandler(accessToken, error);
        });

    });
}

#pragma mark - Profile Management

- (BOOL)updateProfiles:(NSError **)error
{
    NSError *requestError;
    SinglyRequest *request = [SinglyRequest requestWithEndpoint:@"profile" andParameters:@{ @"auth" : @"true" }];
    SinglyConnection *connection = [SinglyConnection connectionWithRequest:request];
    id responseObject = [connection performRequest:&requestError];

    // Check for invalid or expired tokens...
    if (requestError)
    {
        SinglyLog(@"An error occurred while requesting profiles: %@", requestError);

        // Reset Profiles
        _profile = nil;
        _profiles = nil;

        // If the access token has become invalid, reset the session...
        if ([requestError.domain isEqualToString:kSinglyErrorDomain] && requestError.code == kSinglyInvalidAccessTokenErrorCode)
        {
            SinglyLog(@"Access token is invalid or expired! Need to reauthorize...");
            [self resetSession];
        }

        if (error) *error = requestError;

        return NO;
    }

    NSDictionary *serviceProfiles = responseObject[@"services"];
    _profiles = serviceProfiles;
    _profile = responseObject;

    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter postNotificationName:kSinglySessionProfilesUpdatedNotification
                                                          object:self];
    });

    return YES;
}

- (void)updateProfilesWithCompletion:(void (^)(BOOL isSuccessful, NSError *error))completionHandler
{
    dispatch_queue_t currentQueue = dispatch_get_current_queue();
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{

        NSError *error;
        BOOL isSuccessful = [self updateProfiles:&error];

        if (completionHandler) dispatch_sync(currentQueue, ^{
            completionHandler(isSuccessful, error);
        });

    });
}

- (BOOL)resetProfiles
{

    // Reset Profiles
    _profile = nil;
    _profiles = nil;

    // Post Notification
    [[NSNotificationCenter defaultCenter] postNotificationName:kSinglySessionProfilesUpdatedNotification
                                                        object:self];

    return YES;

}

#pragma mark - Service Management

- (void)applyService:(NSString *)serviceIdentifier
           withToken:(NSString *)accessToken // DEPRECATED
{
    [self applyService:serviceIdentifier withToken:accessToken error:nil];
}

- (BOOL)applyService:(NSString *)serviceIdentifier
           withToken:(NSString *)accessToken
               error:(NSError **)error
{
    return [self applyService:serviceIdentifier withToken:accessToken tokenSecret:nil error:error];
}

- (BOOL)applyService:(NSString *)serviceIdentifier
           withToken:(NSString *)accessToken
         tokenSecret:(NSString *)tokenSecret
               error:(NSError **)error
{

    //    NSLog(@"[SinglySDK] Applying service '%@' with token '%@' to the Singly service ...", serviceIdentifier, accessToken);

    // Prepare the Request
    SinglyRequest *request = [[SinglyRequest alloc] initWithEndpoint:[NSString stringWithFormat:@"auth/%@/apply", serviceIdentifier]];
    if (tokenSecret)
        request.parameters = @{
            @"client_id": self.clientID,
            @"client_secret": self.clientSecret,
            @"token": accessToken,
            @"token_secret": tokenSecret
        };
    else
        request.parameters = @{
            @"client_id": self.clientID,
            @"client_secret": self.clientSecret,
            @"token": accessToken
        };

    // Perform the Request
    NSError *requestError;
    SinglyConnection *connection = [SinglyConnection connectionWithRequest:request];
    NSDictionary *responseDictionary = [connection performRequest:&requestError];

    // Check for Errors
    if (requestError)
    {
        if (error) *error = requestError;
        return NO;
    }

    SinglySession.sharedSession.accessToken = responseDictionary[@"access_token"];
    SinglySession.sharedSession.accountID = responseDictionary[@"account"];

    NSError *profilesError;
    [SinglySession.sharedSession updateProfiles:&profilesError];
    if (profilesError)
    {
        if (error) *error = profilesError;
        return NO;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter postNotificationName:kSinglyServiceAppliedNotification
                                                          object:serviceIdentifier];
    });
    
    return YES;

}

- (void)applyService:(NSString *)serviceIdentifier
           withToken:(NSString *)accessToken
          completion:(SinglyApplyServiceCompletionBlock)completionHandler
{
    [self applyService:serviceIdentifier
             withToken:accessToken
           tokenSecret:nil
            completion:completionHandler];
}

- (void)applyService:(NSString *)serviceIdentifier
           withToken:(NSString *)accessToken
         tokenSecret:(NSString *)tokenSecret
          completion:(SinglyApplyServiceCompletionBlock)completionHandler
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{

        NSError *error;
        BOOL isApplied = [self applyService:serviceIdentifier withToken:accessToken tokenSecret:tokenSecret error:&error];

        if (completionHandler) completionHandler(isApplied, error);

    });
}

#pragma mark - Device Contacts

- (void)syncDeviceContacts // DEPRECATED
{
    [self syncDeviceContactsWithCompletion:nil];
}

- (BOOL)syncDeviceContacts:(NSError **)error
{
    
    // Only allow a single sync operation to be performed at a given time.
    if (self.isSyncingDeviceContacts) return NO;
    _isSyncingDeviceContacts = YES;

    ABAddressBookRef addressBook;
    __block BOOL isAuthorized = NO;

    // On iOS 6+ we need to ask the user for permission to access their contacts.
    if (ABAddressBookCreateWithOptions != NULL)
    {
        dispatch_semaphore_t accessSemaphore = dispatch_semaphore_create(0);
        addressBook = ABAddressBookCreateWithOptions(NULL, NULL);
        ABAddressBookRequestAccessWithCompletion(addressBook, ^(bool granted, CFErrorRef error) {
            isAuthorized = granted;
            dispatch_semaphore_signal(accessSemaphore);
        });
        dispatch_semaphore_wait(accessSemaphore, DISPATCH_TIME_FOREVER);
    }

    // iOS 5.x
    else
    {
        addressBook = ABAddressBookCreate();
        isAuthorized = YES;
    }

    // If we are not authorized, notify the user that they will need to allow
    // the app to access their contacts in order to perform a sync.
    if (!isAuthorized)
    {
        // TODO Return an error, don't present UI...
        SinglyAlertView *alertView = [[SinglyAlertView alloc] initWithTitle:nil message:@"Unable to sync contacts because we are not allowed to access the contacts on this device. Please enable access for this app in Settings."];
        [alertView addCancelButtonWithTitle:@"Dismiss"];
        [alertView show];
        _isSyncingDeviceContacts = NO;
        return NO;
    }

    NSArray *allContacts = (__bridge_transfer NSArray *)ABAddressBookCopyArrayOfAllPeople(addressBook);
    NSMutableArray *contactsToSync = [NSMutableArray arrayWithCapacity:allContacts.count];
    for (int i = 0; i < allContacts.count; i++)
    {

        ABRecordRef contactReference = (__bridge ABRecordRef)allContacts[i];
        NSMutableDictionary *contact = [NSMutableDictionary dictionary];

        // Record ID
        contact[@"id"] = [NSString stringWithFormat:@"%d", ABRecordGetRecordID(contactReference)];

        // Name
        contact[@"name"] = [NSString stringWithFormat:@"%@ %@", ABRecordCopyValue(contactReference, kABPersonFirstNameProperty), ABRecordCopyValue(contactReference, kABPersonLastNameProperty)];

        // Phone Numbers
        NSArray *phoneNumbers = ((__bridge_transfer NSArray *)ABMultiValueCopyArrayOfAllValues(ABRecordCopyValue(contactReference, kABPersonPhoneProperty)));
        if (phoneNumbers.count > 0) contact[@"phones"] = phoneNumbers;

        // Email Addresses
        NSArray *emailAddresses = ((__bridge_transfer NSArray *)ABMultiValueCopyArrayOfAllValues(ABRecordCopyValue(contactReference, kABPersonEmailProperty)));
        if (emailAddresses.count > 0) contact[@"emails"] = emailAddresses;

        // Self? (Determined Below...)
        contact[@"self"] = @"false";

        [contactsToSync addObject:contact];
    }

    // Release the address book reference, as we no longer need it to continue.
    CFRelease(addressBook);

    NSDictionary *singlyProfile = SinglySession.sharedSession.profile;
    NSDictionary *ownerProfile;

    // Attempt to determine who the device owner is by comparing their Singly
    // profile against the local address book.
    // TODO Match singly profile against more attributes in the local address book
    for (NSMutableDictionary *contact in contactsToSync)
    {
        // ... comparing e-mail addresses
        NSPredicate *emailPredicate = [NSPredicate predicateWithFormat:@"SELF IN %@", contact[@"emails"]];
        BOOL isFound = [emailPredicate evaluateWithObject:singlyProfile[@"email"]];
        if (isFound)
        {
            contact[@"self"] = @"true";
            ownerProfile = contact;
            break;
        }
    }

    if (!ownerProfile)
        SinglyLog(@"Unable to determine self for contacts sync!");

    // Serialize Contacts
    NSError *serializationError;
    NSData *serializedContacts = [NSJSONSerialization dataWithJSONObject:contactsToSync options:kNilOptions error:&serializationError];
    if (serializationError)
    {
        SinglyLog(@"Serialization error while preparing contacts for syncing: %@", serializationError);
        if (error) *error = serializationError;
        _isSyncingDeviceContacts = NO;
        return NO;
    }

    // Prepare the Request
    SinglyRequest *syncRequest = [SinglyRequest requestWithEndpoint:@"friends/ios"];
    [syncRequest setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [syncRequest setHTTPMethod:@"POST"];
    [syncRequest setHTTPBody:serializedContacts];

    // Perform the Request
    NSError *syncError;
    SinglyConnection *connection = [SinglyConnection connectionWithRequest:syncRequest];
    [connection performRequest:&syncError];
    if (syncError)
    {
        if (error) *error = syncError;
        _isSyncingDeviceContacts = NO;
        return NO;
    }

    _isSyncingDeviceContacts = NO;

    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter postNotificationName:kSinglyContactsSyncedNotification
                                                          object:nil];
    });

    return YES;
}

- (void)syncDeviceContactsWithCompletion:(void (^)(BOOL isSuccessful, NSError *error))completionHandler
{
    dispatch_queue_t currentQueue = dispatch_get_current_queue();
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{

        NSError *error;
        BOOL isSuccessful = [self syncDeviceContacts:&error];

        if (completionHandler) dispatch_sync(currentQueue, ^{
            completionHandler(isSuccessful, error);
        });

    });
}

#pragma mark - URL Handling

- (BOOL)handleOpenURL:(NSURL *)url
{
    NSError *error;

    // Facebook
    if ([url.scheme hasPrefix:@"fb"])
    {
        NSString *accessToken = [url extractAccessToken];
        if (accessToken)
        {
            [SinglySession.sharedSession applyService:@"facebook" withToken:accessToken error:&error];

            if (error)
            {
                // TODO Handle Errors
            }
            return YES;
        }
    }

    return NO;
}

@end

