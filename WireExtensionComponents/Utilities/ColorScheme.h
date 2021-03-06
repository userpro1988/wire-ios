// 
// Wire
// Copyright (C) 2016 Wire Swiss GmbH
// 
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
// 
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
// 
// You should have received a copy of the GNU General Public License
// along with this program. If not, see http://www.gnu.org/licenses/.
// 


#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>


extern NSString * const ColorSchemeColorTextForeground;
extern NSString * const ColorSchemeColorTextBackground;
extern NSString * const ColorSchemeColorTextDimmed;
extern NSString * const ColorSchemeColorTextPlaceholder;

extern NSString * const ColorSchemeColorAccent;
extern NSString * const ColorSchemeColorAccentDimmed;
extern NSString * const ColorSchemeColorAccentDimmedFlat;
extern NSString * const ColorSchemeColorAccentDarken;

extern NSString * const ColorSchemeColorIconNormal;
extern NSString * const ColorSchemeColorIconSelected;
extern NSString * const ColorSchemeColorIconHighlighted;
extern NSString * const ColorSchemeColorIconBackgroundSelected;
extern NSString * const ColorSchemeColorIconBackgroundSelectedNoAccent;
extern NSString * const ColorSchemeColorIconShadow;
extern NSString * const ColorSchemeColorIconHighlight;

extern NSString * const ColorSchemeColorTabNormal;
extern NSString * const ColorSchemeColorTabSelected;
extern NSString * const ColorSchemeColorTabHighlighted;

extern NSString * const ColorSchemeColorBackground;
extern NSString * const ColorSchemeColorSeparator;
extern NSString * const ColorSchemeColorBackgroundOverlay;
extern NSString * const ColorSchemeColorBackgroundOverlayWithoutPicture;
extern NSString * const ColorSchemeColorPlaceholderBackground;
extern NSString * const ColorSchemeColorAvatarBorder;
extern NSString * const ColorSchemeColorLoadingDotActive;
extern NSString * const ColorSchemeColorLoadingDotInactive;


typedef NS_ENUM(NSUInteger, ColorSchemeVariant) {
    ColorSchemeVariantLight,
    ColorSchemeVariantDark
};


@interface ColorScheme : NSObject

@property (nonatomic, readonly) NSDictionary *colors;
@property (nonatomic, readonly) UIKeyboardAppearance keyboardAppearance;
@property (nonatomic, readonly) UIBlurEffectStyle blurEffectStyle;

@property (nonatomic) UIColor *accentColor;
@property (nonatomic) ColorSchemeVariant variant;

+ (instancetype)defaultColorScheme;

+ (UIKeyboardAppearance)keyboardAppearanceForVariant:(ColorSchemeVariant)variant;
+ (UIBlurEffectStyle)blurEffectStyleForVariant:(ColorSchemeVariant)variant;

- (UIColor *)colorWithName:(NSString *)colorName;
- (UIColor *)colorWithName:(NSString *)colorName variant:(ColorSchemeVariant)variant;

@end
