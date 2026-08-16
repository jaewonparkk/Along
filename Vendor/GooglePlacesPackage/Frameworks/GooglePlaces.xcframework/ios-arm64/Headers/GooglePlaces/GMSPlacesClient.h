//
//  GMSPlacesClient.h
//  Google Places SDK for iOS
//
//  Copyright 2016 Google LLC
//
//  Usage of this SDK is subject to the Google Maps/Google Earth APIs Terms of
//  Service: https://cloud.google.com/maps-platform/terms
//

#import <CoreLocation/CoreLocation.h>
#import <UIKit/UIKit.h>


#import "GMSPlace.h"
#import "GMSPlacesDeprecationUtils.h"
#import "GMSPlacesErrors.h"

@class GMSAutocompleteFilter;
@class GMSAutocompletePrediction;
@class GMSAutocompleteSessionToken;
@class GMSAutocompleteRequest;
@class GMSAutocompleteSuggestion;
@class GMSPlace;
@class GMSPlaceLikelihood;
@class GMSPlaceLikelihoodList;
@class GMSPlacePhotoMetadata;
@class GMSPlacePhotoMetadataList;
@class GMSPlaceSearchByTextRequest;
@class GMSFetchPlaceRequest;
@class GMSFetchPhotoRequest;
@class GMSPlaceSearchNearbyRequest;
@class GMSPlaceIsOpenRequest;
@class GMSPlaceIsOpenResponse;
@class GMSPlaceSearchByTextResponse;
@class GMSPlaceSearchNearbyResponse;

@protocol GMSPlacesAppCheckTokenProvider;


NS_ASSUME_NONNULL_BEGIN

/**
 * Callback type for receiving place details lookups. If an error occurred,
 * `result` will be nil and `error` will contain information about the error.
 * @param result The `GMSPlace` that was returned.
 * @param error The error that occurred, if any.
 *
 * @see `GMSPlacesClient`
 */
typedef void (^GMSPlaceResultCallback)(GMSPlace *_Nullable result, NSError *_Nullable error);


/**
 * Callback type for receiving autocompletion results. `results` is an array of
 * `GMSAutocompletePredictions` representing candidate completions of the query.
 * @param results An array of `GMSAutocompletePrediction`s.
 * @param error The error that occurred, if any.
 *
 * @see `GMSPlacesClient`
 */
typedef void (^GMSAutocompletePredictionsCallback)(
    NSArray<GMSAutocompletePrediction *> *_Nullable results, NSError *_Nullable error)
    __GMS_AVAILABLE_BUT_DEPRECATED_MSG(
        "This method is replaced by <code>GMSAutocompleteSuggestionsCallback</code> "
        "and will be removed in a future release.");

/**
 * Callback type for receiving place photos results. If an error occurred, `photos` will be nil and
 * `error` will contain information about the error.
 * @param photos The result containing `GMSPlacePhotoMetadata` objects.
 * @param error The error that occurred, if any.
 *
 * @see `GMSPlacesClient`
 */


/**
 * Callback type for receiving the open status response. If an error occurred, response will be
 * have a status of `GMSPlaceOpenStatusUnknown` and error will contain information about the error.
 * @param response The `GMSPlaceIsOpenResponse` that was returned.
 * @param error The error that occurred, if any.
 *
 * @see `GMSPlacesClient`
 */
typedef void (^GMSPlaceOpenStatusResponseCallback)(GMSPlaceIsOpenResponse *response,
                                                   NSError *_Nullable error);

/**
 * Callback type for receiving search by text results. `results` is an array of
 * `GMSPlace` representing individual results matching the query.
 * @param results An array of `GMSPlace`s.
 * @param error The error that occurred, if any.
 *
 * @see `GMSPlacesClient`
 */

typedef void (^GMSPlaceSearchByTextResultCallback)(NSArray<GMSPlace *> *_Nullable places,
                                                   NSError *_Nullable error)
    __GMS_AVAILABLE_BUT_DEPRECATED_MSG(
        "This method is replaced by <code>GMSPlaceSearchByTextResponseCallback</code> "
        "and will be removed in a future release.");
/**
 * Callback type for receiving a photo. `photoImage` is a `UIImage`
 * representing the resulting photo matching the specified request.
 * If an error occurred, `photoImage` will be nil and `error` will contain
 * information about the error.
 * @param photoImage A `UIImage` result.
 *
 * @see `GMSPlacesClient`
 */

typedef void (^GMSFetchPhotoResultCallback)(UIImage *_Nullable photoImage,
                                            NSError *_Nullable error);

/**
 * Callback type for autocomplete results.
 * @param results An array of `GMSAutocompleteSuggestion`.
 * @param error The error that occurred, if any.
 *
 * @see `GMSPlacesClient`
 */
typedef void (^GMSAutocompleteSuggestionsCallback)(
    NSArray<GMSAutocompleteSuggestion *> *_Nullable results, NSError *_Nullable error);

/**
 * Callback type for receiving search nearby results.
 * @param places An array of `GMSPlace`
 * @param error The error that occurred, if any.
 *
 * @see `GMSPlacesClient`
 */
typedef void (^GMSPlaceSearchNearbyResultCallback)(NSArray<GMSPlace *> *_Nullable places,
                                                   NSError *_Nullable error)
    __GMS_AVAILABLE_BUT_DEPRECATED_MSG(
        "This method is replaced by <code>GMSPlaceSearchNearbyResponseCallback</code> "
        "and will be removed in a future release.");

/**
 * Callback type for receiving the search by text response. `response` is
 * `GMSPlaceSearchByTextResponse` representing a list of places and other attributes about the
 * places.
 *
 * @param response Search response containing a list of places and potential other attributes about
 *                 the places.
 * @param error The error that occurred, if any.
 *
 * @see `GMSPlacesClient`
 */
typedef void (^GMSPlaceSearchByTextResponseCallback)(
    GMSPlaceSearchByTextResponse *_Nullable response, NSError *_Nullable error);

/**
 * Callback type for receiving search nearby response. `response` is `GMSPlaceSearchNearbyResponse`
 * representing a list of places and other attributes about the places.
 *
 * @param response Search response containing a list of places and potential other attributes about
 *                 the places.
 * @param error The error that occurred, if any.
 *
 * @see `GMSPlacesClient`
 */
typedef void (^GMSPlaceSearchNearbyResponseCallback)(
    GMSPlaceSearchNearbyResponse *_Nullable response, NSError *_Nullable error);

/**
 * Main interface to the Places SDK. Used for searching and getting details about places. This class
 * should be accessed through the `[GMSPlacesClient sharedClient]` method.
 *
 * `GMSPlacesClient` methods should only be called from the main thread. Calling these methods from
 * another thread will result in an exception or undefined behavior. Unless otherwise specified, all
 * callbacks will be invoked on the main thread.
 */
@interface GMSPlacesClient : NSObject

/**
 * Provides the shared instance of `GMSPlacesClient` for the Google Places SDK for iOS, creating it
 * if necessary.
 *
 * If your application often uses methods of `GMSPlacesClient` it may want to hold onto this object
 * directly, as otherwise your connection to Google may be restarted on a regular basis.
 */
+ (instancetype)sharedClient;

/**
 * Provides your API key to the Google Places SDK for iOS. This key is generated for your
 * application via the Google Cloud Platform Console, and is paired with your application's
 * bundle ID to identify it. This should be called by your application before using
 * `GMSPlacesClient` (e.g., in `application:didFinishLaunchingWithOptions:`).
 *
 * @return YES if the APIKey was successfully provided.
 */
+ (BOOL)provideAPIKey:(NSString *)key;

/**
 * Provides an App Check token provider to the Google Places SDK for iOS.  This should be called by
 * your application before using `GMSPlacesClient`
 * (for example, in `application:didFinishLaunchingWithOptions:`). If you do not provide a token
 * provider, the SDK will not use the token provider.
 */
+ (void)setAppCheckTokenProvider:(id<GMSPlacesAppCheckTokenProvider>)provider;

/**
 * Returns the open source software license information for the Google Places SDK for iOS. This
 * information must be made available within your application.
 */
+ (NSString *)openSourceLicenseInfo;

/** Returns the version for this release of the Google Places SDK for iOS.. For example, "1.0.0". */
+ (NSString *)SDKVersion;

/**
 * Returns the long version for this release of the Google Places SDK for iOS.. For example, "1.0.0
 * (102.1)".
 */
+ (NSString *)SDKLongVersion;


/**
 * Find Autocomplete suggestions from text query. Results may optionally be biased towards a
 * certain location or restricted to an area. This method is non-blocking.
 *
 * The supplied callback will be invoked with an array of autocompletion suggestions upon success
 * and an `NSError` upon an error.
 *
 * @param request The `GMSAutocompleteRequest` request for autocomplete.
 * @param callback The callback to invoke with the suggestions.
 */
- (void)fetchAutocompleteSuggestionsFromRequest:(GMSAutocompleteRequest *)request
                                       callback:(GMSAutocompleteSuggestionsCallback)callback;


/**
 * Gets the metadata for up to 10 photos associated with a place.
 *
 * Photos are sourced from a variety of locations, including business owners and photos contributed
 * by Google+ users. In most cases, these photos can be used without attribution, or will have the
 * required attribution included as a part of the image. However, you must use the `attributions`
 * property in the response to retrieve any additional attributions required, and display those
 * attributions in your application wherever you display the image. A maximum of 10 photos are
 * returned.
 *
 * Multiple calls of this method will probably return the same photos each time. However, this is
 * not guaranteed because the underlying data may have changed.
 *
 * This method performs a network lookup.
 *
 * @param placeID The place ID for which to look up photos.
 * @param callback The callback to invoke with the lookup result.
 */



/**
 * Gets the open status for a place.
 *
 * Gets details for a place including all properties necessary to determine `GMSPlaceOpenStatus` at
 * the specified `NSDate`.
 *
 * This method is non-blocking.
 *
 * **NOTE:** It is best practice to check that opening hours are not null before passing in a
 * `GMSPlace` (with opening hours already requested) to `GMSPlaceIsOpenRequest`. In some cases, a
 * place may not have any opening hours data available. If a place request with the opening hours
 * property has already been made, and opening hours are null, calling this method using the place
 * response object will result in another billable event.
 *
 * @param isOpenRequest The request to determine the open status for a given place.
 * @param callback The callback to invoke with the open status response.
 */
- (void)isOpenWithRequest:(GMSPlaceIsOpenRequest *)isOpenRequest
                 callback:(GMSPlaceOpenStatusResponseCallback)callback;

/**
 * Search for places by text and restrictions. This method is non-blocking.
 * @param textSearchRequest `GMSPlaceSearchByTextRequest` The text request to use for the query.
 * @param callback The callback to invoke with the lookup result.
 */

- (void)searchByTextWithRequest:(GMSPlaceSearchByTextRequest *)textSearchRequest
                       callback:(GMSPlaceSearchByTextResultCallback)callback
    __GMS_AVAILABLE_BUT_DEPRECATED_MSG(
        "This method is replaced by <code>searchByTextWithRequest:completion:</code> "
        "and will be removed in a future release.");

/**
 * Get a place using a request object. This method is non-blocking.
 * @param fetchPlaceRequest `GMSFetchPlaceRequest` The fetch place request to use for the query.
 * @param callback The callback to invoke with the place result.
 */
- (void)fetchPlaceWithRequest:(GMSFetchPlaceRequest *)fetchPlaceRequest
                     callback:(GMSPlaceResultCallback)callback;

/**
 * Request a photo using fetch photo request. This method is non-blocking.
 * @param fetchPhotoRequest `GMSFetchPhotoRequest` The photo request to use.
 * @param callback The callback to invoke with the `NSURL` result.
 */

- (void)fetchPhotoWithRequest:(GMSFetchPhotoRequest *)fetchPhotoRequest
                     callback:(GMSFetchPhotoResultCallback)callback
    __GMS_AVAILABLE_BUT_DEPRECATED_MSG(
        "This API is deprecated, please use the Place Details component "
        "(https://developers.google.com/maps/documentation/places/ios-sdk/place-details-ui-kit) "
        "instead.")
        ;

/**
 * Search for places near a location and restriction. This method is non-blocking.
 * @param searchNearbyRequest `GMSPlaceSearchNearbyRequest` The search nearby request to use for
 * the query.
 * @param callback The callback to invoke with the lookup result.
 */
- (void)searchNearbyWithRequest:(GMSPlaceSearchNearbyRequest *)searchNearbyRequest
                       callback:(GMSPlaceSearchNearbyResultCallback)callback
    __GMS_AVAILABLE_BUT_DEPRECATED_MSG(
        "This method is replaced by <code>searchNearbyWithRequest:completion:</code> "
        "and will be removed in a future release.");

/**
 * Search for places by text and restrictions. This method is non-blocking.
 * @param textSearchRequest `GMSPlaceSearchByTextRequest` The text request to use for the query.
 * @param callback The callback to invoke with the search response.
 */

- (void)searchByTextWithRequest:(GMSPlaceSearchByTextRequest *)textSearchRequest
                     completion:(GMSPlaceSearchByTextResponseCallback)callback;

/**
 * Search for places near a location and restriction. This method is non-blocking.
 * @param searchNearbyRequest `GMSPlaceSearchNearbyRequest` The search nearby request to use for
 * the query.
 * @param callback The callback to invoke with the search response.
 */
- (void)searchNearbyWithRequest:(GMSPlaceSearchNearbyRequest *)searchNearbyRequest
                     completion:(GMSPlaceSearchNearbyResponseCallback)callback;

/**
 * Adds a usage attribution ID to the initializer, which helps Google understand which libraries and
 * samples are helpful to developers, such as usage of a marker clustering library.
 * To opt out of sending the usage attribution ID, it is safe to delete this function call or
 * replace the value with an empty string.
 *
 * @param internalUsageAttributionId The usage attribution ID to add
 */
+ (void)addInternalUsageAttributionID:(NSString *)internalUsageAttributionID;

@end

NS_ASSUME_NONNULL_END
