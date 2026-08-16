//
//  GMSPlacePhotoMetadata.h
//  Google Places SDK for iOS
//
//  Copyright 2016 Google LLC
//
//  Usage of this SDK is subject to the Google Maps/Google Earth APIs Terms of
//  Service: https://cloud.google.com/maps-platform/terms
//

#import <UIKit/UIKit.h>

#import "GMSPlacesDeprecationUtils.h"

@class GMSPlaceAuthorAttribution;

NS_ASSUME_NONNULL_BEGIN

/** The metadata corresponding to a single photo associated with a place. */
__GMS_AVAILABLE_BUT_DEPRECATED_MSG(
    "This class is deprecated, please use the Place Details component "
    "(https://developers.google.com/maps/documentation/places/ios-sdk/place-details-ui-kit) "
    "instead.")
@interface GMSPlacePhotoMetadata : NSObject

/**
 * The data provider attribution string for this photo.
 *
 * These are provided as a NSAttributedString, which may contain hyperlinks to the website of each
 * provider.
 *
 * In general, these must be shown to the user if data from this `GMSPlacePhotoMetadata` is shown,
 * as described in the Places SDK Terms of Service.
 */
@property(nonatomic, readonly, copy, nullable) NSAttributedString *attributions;

/** The author attributions that must be shown to the user if this photo is displayed. */
@property(nonatomic, readonly, copy, nullable)
    NSArray<GMSPlaceAuthorAttribution *> *authorAttributions;

/** The maximum pixel size in which this photo is available. */
@property(nonatomic, readonly, assign) CGSize maxSize;

/** A link where users can flag a problem with the photo. */
@property(nonatomic, readonly, copy, nullable) NSURL *flagContentURL;

/** A link to show the photo on Google Maps. */
@property(nonatomic, readonly, copy, nullable) NSURL *googleMapsURL;

/** Initializer is not available. */
- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
