//
//  GMSPlacePhotoMetadataList.h
//  Google Places SDK for iOS
//
//  Copyright 2016 Google LLC
//
//  Usage of this SDK is subject to the Google Maps/Google Earth APIs Terms of
//  Service: https://cloud.google.com/maps-platform/terms
//

#import <UIKit/UIKit.h>

#import "GMSPlacePhotoMetadata.h"
#import "GMSPlacesDeprecationUtils.h"

NS_ASSUME_NONNULL_BEGIN

/** A list of `GMSPlacePhotoMetadata` objects. */
__GMS_AVAILABLE_BUT_DEPRECATED_MSG(
    "This class is deprecated, please use the Place Details component "
    "(https://developers.google.com/maps/documentation/places/ios-sdk/place-details-ui-kit) "
    "instead.")
@interface GMSPlacePhotoMetadataList : NSObject

/** The array of `GMSPlacePhotoMetadata` objects. */
@property(nonatomic, readonly, copy) NSArray<GMSPlacePhotoMetadata *> *results;

@end

NS_ASSUME_NONNULL_END
