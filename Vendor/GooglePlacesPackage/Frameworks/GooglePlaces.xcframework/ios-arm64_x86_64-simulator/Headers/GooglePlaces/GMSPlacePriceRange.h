//
//  GMSPlacePriceRange.h
//  Google Places SDK for iOS
//
//  Copyright 2026 Google LLC
//
//  Usage of this SDK is subject to the Google Maps/Google Earth APIs Terms of
//  Service: https://cloud.google.com/maps-platform/terms
//

#import <Foundation/Foundation.h>



#import "GMSPlaceMoney.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Price range associated with a place. When price range information is available for a
 * place, the start price will always be set but the end price may not always be set.
 * This indicates a range without an upper bound (eg: "More than $100").
 */
@interface GMSPlacePriceRange : NSObject

/** The start value of the price range. */
@property(nonatomic, readonly, nullable) GMSPlaceMoney *startPrice;

/** The end value of the price range. */
@property(nonatomic, readonly, nullable) GMSPlaceMoney *endPrice;

- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
