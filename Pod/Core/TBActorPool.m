//
//  TBActorPool.m
//  ActorKit
//
//  Created by Julian Krumow on 05.08.15.
//  Copyright (c) 2015 Julian Krumow. All rights reserved.
//

#import "TBActorPool.h"
#import "TBActorProxySync.h"
#import "TBActorProxyAsync.h"

static NSString * const TBAKActorPoolQueue = @"com.tarbrain.ActorKit.TBActorPool";

@interface TBActorPool ()
@property (nonatomic, strong) NSArray *priv_actors;
@end

@implementation TBActorPool

- (instancetype)initWithActors:(NSArray *)actors
{
    self = [super init];
    if (self) {
        _priv_actors = actors;
        self.name = TBAKActorPoolQueue;
    }
    return self;
}

- (NSArray *)actors
{
    return self.priv_actors.copy;
}

- (id)sync
{
    return [TBActorProxySync proxyWithActors:self.actors];
}

- (id)async
{
    return [TBActorProxyAsync proxyWithActors:self.actors];
}

- (void)subscribeToPublisher:(id)publisher withMessageName:(NSString *)messageName selector:(SEL)selector
{
    [self.subscriptions addObject:messageName];
    
    [[NSNotificationCenter defaultCenter] addObserverForName:messageName
                                                      object:publisher
                                                       queue:self
                                                  usingBlock:^(NSNotification *note) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                                                      [self.sync performSelector:selector withObject:note.userInfo];
#pragma clang diagnostic pop
                                                  }];
}

@end