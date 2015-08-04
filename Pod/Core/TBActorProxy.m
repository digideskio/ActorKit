//
//  TBActorProxy.m
//  ActorKit
//
//  Created by Julian Krumow on 03.08.15.
//  Copyright (c) 2015 Julian Krumow. All rights reserved.
//

#import "TBActorProxy.h"
#import "TBActor.h"
#import "NSException+ActorKit.h"


@implementation TBActorProxy

+ (TBActorProxy *)proxyWithActor:(TBActor *)actor
{
    @throw [NSException tbak_abstractClassException:[TBActorProxy class]];
    return nil;
}

- (instancetype)initWithActor:(TBActor *)actor
{
    if (self.class == TBActorProxy.class) {
        @throw [NSException tbak_abstractClassException:[TBActorProxy class]];
    }
    _actor = actor;
    return self;
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector
{
    return [self.actor methodSignatureForSelector:selector];
}

- (void)forwardInvocation:(NSInvocation *)invocation
{
    [self.actor addOperationWithBlock:^{
        [invocation invokeWithTarget:self.actor];
    }];
}

@end
