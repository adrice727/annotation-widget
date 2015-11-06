//
//  OTPath.h
//  OTAnnotations
//
//  Created by Trevor Boyer on 9/26/15.
//  Copyright © 2015 TokBox, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface OTPath : NSObject

@property (nonatomic) UIBezierPath* bezierPath;
@property (nonatomic) UIColor* color;
@property (nonatomic) NSString* canvasId;

@end
