//
//  TBActorPool+ActorKitSupervision.m
//  ActorKitSupervision
//
//  Created by Julian Krumow on 23.11.15.
//  Copyright (c) 2015 Julian Krumow. All rights reserved.
//

#import "TBActorPool+ActorKitSupervision.h"
#import "NSObject+ActorKitSupervision.h"

@implementation TBActorPool (ActorKitSupervision)

- (void)crashWithError:(NSError *)error
{
    [self.supervisor.sync pool:self didCrashWithError:error];
}

- (void)crashWithActor:(NSObject *)actor error:(NSError *)error
{
    [self.supervisor.sync actor:actor inPool:self didCrashWithError:error];
}

@end
