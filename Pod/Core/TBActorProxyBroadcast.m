//
//  TBActorProxyBroadcast.m
//  ActorKit
//
//  Created by Julian Krumow on 15.09.15.
//  Copyright (c) 2015 Julian Krumow. All rights reserved.
//

#import "TBActorProxyBroadcast.h"
#import "NSInvocation+ActorKit.h"
#import "NSObject+ActorKit.h"
#import "TBActorOperation.h"

@implementation TBActorProxyBroadcast

- (instancetype)initWithPool:(TBActorPool *)pool
{
    _pool = pool;
    return self;
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector
{
    return [self.pool.actors.firstObject methodSignatureForSelector:selector];
}

- (void)forwardInvocation:(NSInvocation *)invocation
{
    for (NSObject *actor in self.pool.actors) {
        
        NSInvocation *forwardInvocation = invocation.tbak_copy;
        forwardInvocation.target = actor;
        
        TBActorOperation *operation = [[TBActorOperation alloc] initWithInvocation:forwardInvocation];
        operation.completionBlock = ^{
            [self.pool relinquishActor:actor];
        };
        [actor.actorQueue addOperation:operation];
    }
}

@end
