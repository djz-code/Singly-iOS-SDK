//
//  SinglyLoginViewController+Internal.h
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

@interface SinglyLoginViewController ()

/**
 *
 * Response data received during the connection process.
 *
 * @available Available in Singly iOS SDK 1.0.0 and later.
 *
**/
@property (strong) NSMutableData *responseData;

/**
 *
 *
 *
 * @available Available in Singly iOS SDK 1.0.0 and later.
 *
**/
@property (nonatomic, strong) UIView *pendingLoginView;

/**
 *
 *
 *
 * @available Available in Singly iOS SDK 1.0.0 and later.
 *
**/
@property (nonatomic, strong) UIActivityIndicatorView *activityView;

/**
 *
 * The web view that will handle loading of the service login location.
 *
 * @available Available in Singly iOS SDK 1.0.0 and later.
 *
**/
@property (nonatomic, strong) UIWebView *webView;

/**
 *
 * A custom navigation bar instance that is used when this view controller is
 * presented modally.
 *
 * @available Available in Singly iOS SDK 1.0.0 and later.
 *
**/
@property (nonatomic, strong) UINavigationBar *navigationBar;

@end
