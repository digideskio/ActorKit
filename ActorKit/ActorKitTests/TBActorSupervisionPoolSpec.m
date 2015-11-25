//
//  TBActorSupervisionPoolSpec.m
//  ActorKitTests
//
//  Created by Julian Krumow on 09.10.15.
//  Copyright © 2015 Julian Krumow. All rights reserved.
//

#import <ActorKit/Supervision.h>

#import "TestActor.h"

SpecBegin(TBActorSupervisionPool)

__block TBActorSupervisionPool *actors;
__block dispatch_queue_t testQueue;
__block dispatch_queue_t testQueue2;
__block dispatch_queue_t completionQueue;
__block dispatch_queue_t completionQueue2;
__block NSMutableArray *results;
__block NSMutableArray *results2;
__block size_t taskCount = 25;

describe(@"TBActorSupervisionPool", ^{
    
    beforeEach(^{
        actors = [TBActorSupervisionPool new];
        testQueue = dispatch_queue_create("testQueue", DISPATCH_QUEUE_CONCURRENT);
        completionQueue = dispatch_queue_create("completionQueue", DISPATCH_QUEUE_SERIAL);
        testQueue2 = dispatch_queue_create("testQueue2", DISPATCH_QUEUE_CONCURRENT);
        completionQueue2 = dispatch_queue_create("completionQueue2", DISPATCH_QUEUE_SERIAL);
        results = [NSMutableArray new];
        results2 = [NSMutableArray new];
    });
    
    afterEach(^{
        actors = nil;
        testQueue = nil;
        completionQueue = nil;
        testQueue2 = nil;
        completionQueue2 = nil;
        results = nil;
        results2 = nil;
    });
    
    it(@"creates a singleton instance", ^{
        TBActorSupervisionPool *instanceOne = [TBActorSupervisionPool sharedInstance];
        TBActorSupervisionPool *instanceTwo = [TBActorSupervisionPool sharedInstance];
        
        expect(instanceOne).to.equal(instanceTwo);
    });
    
    it(@"creates an actor based on a creation block", ^{
        [actors superviseWithId:@"master" creationBlock:^(NSObject **actor) {
            *actor = [TestActor new];
        }];
        
        TestActor *master = actors[@"master"];
        expect(master).notTo.beNil;
        
        master.uuid = @(1);
        NSNumber *uuid = [[actors[@"master"] sync] uuid];
        expect(uuid).to.equal(1);
    });
    
    it(@"returns supervisors by given actor ids", ^{
        [actors superviseWithId:@"master" creationBlock:^(NSObject **actor) {
            *actor = [TestActor new];
        }];
        
        NSArray *supervisors = [actors supervisorsForIds:[NSSet setWithObjects:@"master", @"none", nil]];
        expect(supervisors).to.haveACountOf(1);
        
        TBActorSupervisor *supervisor = supervisors.firstObject;
        expect(supervisor.Id).to.equal(@"master");
    });
    
    it(@"returns the id of a given actor instance", ^{
        [actors superviseWithId:@"master" creationBlock:^(NSObject **actor) {
            *actor = [TestActor new];
        }];
        TestActor *actor = actors[@"master"];
        TestActor *otherActor = [TestActor new];
        
        expect([actors idForActor:actor]).to.equal(@"master");
        expect([actors idForActor:otherActor]).to.beNil;
    });
    
    it(@"throws an exception when an Id is already in use", ^{
        [actors superviseWithId:@"master" creationBlock:^(NSObject **actor) {
            *actor = [TestActor new];
        }];
        
        expect(^{
            [actors superviseWithId:@"master" creationBlock:nil];
        }).to.raise(TBAKException);
    });
    
    describe(@"crashes and recreation", ^{
        
        it(@"re-creates an actor after a crash", ^{
            [actors superviseWithId:@"master" creationBlock:^(NSObject **actor) {
                *actor = [TestActor new];
            }];
            
            TestActor *master = actors[@"master"];
            expect(master).notTo.beNil;
            
            // Create state and crash
            master.uuid = @(1);
            [master crashWithError:nil];
            
            TestActor *newMaster = actors[@"master"];
            expect(newMaster).notTo.beNil;
            expect(newMaster).notTo.equal(master);
            expect(newMaster.uuid).to.beNil;
        });
        
        it(@"executes remaining operations on the re-created actor instance after a crash", ^{
            
            [actors superviseWithId:@"master" creationBlock:^(NSObject **actor) {
                *actor = [TestActor new];
            }];
            
            TestActor *master = actors[@"master"];
            
            waitUntil(^(DoneCallback done) {
                dispatch_apply(taskCount, testQueue, ^(size_t index) {
                    [[actors[@"master"] async] address:^(NSString *address) {
                        @synchronized(results) {
                            [results addObject:address];
                            
                            if (results.count == 5) {
                                [master.async doCrash];
                            }
                            if (results.count == taskCount) {
                                done();
                            }
                        }
                    }];
                });
            });
            
            NSLog(@"results: %@", results);
            
            NSCountedSet *set = [NSCountedSet setWithArray:results];
            expect(set.count).to.equal(2);
        });
        
        it(@"re-creates a new actor pool after a crash", ^{
            
            [actors superviseWithId:@"pool" creationBlock:^(NSObject **actor) {
                *actor = [TestActor poolWithSize:2 configuration:nil];
            }];
            
            TBActorPool *pool = actors[@"pool"];
            TestActor *workerOne = pool.actors.allObjects[0];
            TestActor *workerTwo = pool.actors.allObjects[1];
            
            NSLog(@"0: %@", workerOne);
            NSLog(@"1: %@", workerTwo);
            
            dispatch_apply(taskCount, testQueue, ^(size_t index) {
                [[actors[@"pool"] async] addressBlocking:^(NSString *address) {
                    @synchronized(results) {
                        [results addObject:address];
                        
                        if (results.count == 5) {
                            [pool crashWithError:nil];
                        }
                    }
                }];
            });
            
            sleep(1);
            
            TBActorPool *newPool = actors[@"pool"];
            TestActor *newWorkerOne = newPool.actors.allObjects[0];
            TestActor *newWorkerTwo = newPool.actors.allObjects[1];
            
            NSLog(@"0: %@", newWorkerOne);
            NSLog(@"1: %@", newWorkerTwo);
            
            expect(newPool).notTo.equal(pool);
            expect(newPool.actors).notTo.contain(workerOne);
            expect(newPool.actors).notTo.contain(workerTwo);
            
            NSLog(@"results: %@", results);
            
            NSCountedSet *set = [NSCountedSet setWithArray:results];
            expect(set.count).to.equal(4);
        });
        
        it(@"executes remaining operations on the re-created pooled actor instance after a crash", ^{
            
            [actors superviseWithId:@"pool" creationBlock:^(NSObject **actor) {
                *actor = [TestActor poolWithSize:2 configuration:nil];
            }];
            
            TBActorPool *pool = actors[@"pool"];
            TestActor *workerOne = pool.actors.allObjects[0];
            TestActor *workerTwo = pool.actors.allObjects[1];
            
            NSLog(@"0: %@", workerOne);
            NSLog(@"1: %@", workerTwo);
            
            dispatch_apply(taskCount, testQueue, ^(size_t index) {
                [[actors[@"pool"] async] addressBlocking:^(NSString *address) {
                    @synchronized(results) {
                        [results addObject:address];
                        
                        if (results.count == 5) {
                            [workerOne.async doCrash];
                        }
                    }
                }];
            });
            
            sleep(1);
            
            TBActorPool *samePool = actors[@"pool"];
            
            NSLog(@"0: %@", samePool.actors.allObjects[0]);
            NSLog(@"1: %@", samePool.actors.allObjects[1]);
            
            expect(samePool).to.equal(pool);
            
            expect(samePool.actors).notTo.contain(workerOne);
            expect(samePool.actors).to.contain(workerTwo);
            
            NSLog(@"results: %@", results);
            
            NSCountedSet *set = [NSCountedSet setWithArray:results];
            expect(set.count).to.equal(3);
        });
    });
    
    describe(@"linking", ^{
        
        it(@"it recreates linked actors after simultanious crashes", ^{
            [actors superviseWithId:@"master" creationBlock:^(NSObject **actor) {
                *actor = [TestActor new];
            }];
            [actors superviseWithId:@"child" creationBlock:^(NSObject **actor) {
                *actor = [TestActor new];
            }];
            [actors superviseWithId:@"otherChild" creationBlock:^(NSObject **actor) {
                *actor = [TestActor new];
            }];
            [actors superviseWithId:@"child.child" creationBlock:^(NSObject **actor) {
                *actor = [TestActor new];
            }];
            
            [actors linkActor:@"child" toParentActor:@"master"];
            [actors linkActor:@"otherChild" toParentActor:@"master"];
            [actors linkActor:@"child.child" toParentActor:@"master"];
            
            TestActor *master = actors[@"master"];
            TestActor *child = actors[@"child"];
            TestActor *otherChild = actors[@"otherChild"];
            TestActor *childChild = actors[@"child.child"];
            
            // Create state and crash two actors
            master.uuid = @(0);
            child.uuid = @(1);
            otherChild.uuid = @(2);
            childChild.uuid = @(11);
            
            waitUntil(^(DoneCallback done) {
                dispatch_apply(taskCount, testQueue, ^(size_t index) {
                    [[actors[@"master"] async] address:^(NSString *address) {
                        @synchronized(results) {
                            [results addObject:address];
                            
                            if (results.count == 5) {
                                [master.async doCrash];
                            }
                            if (results.count == taskCount && results2.count == taskCount) {
                                done();
                            }
                        }
                    }];
                    
                    [[actors[@"child.child"] async] address:^(NSString *address) {
                        @synchronized(results) {
                            [results2 addObject:address];
                            
                            if (results2.count == 5) {
                                [childChild.async doCrash];
                            }
                            if (results.count == taskCount && results2.count == taskCount) {
                                done();
                            }
                        }
                    }];
                });
            });
            
            TestActor *newMaster = actors[@"master"];
            TestActor *newChild = actors[@"child"];
            TestActor *newOtherChild = actors[@"otherChild"];
            TestActor *newChildChild = actors[@"child.child"];
            
            expect(newMaster).notTo.beNil;
            expect(newChild).notTo.beNil;
            expect(newOtherChild).notTo.beNil;
            expect(newChildChild).notTo.beNil;
            
            expect(newMaster).notTo.equal(master);
            expect(newChild).notTo.equal(child);
            expect(newOtherChild).notTo.equal(otherChild);
            expect(newChildChild).notTo.equal(childChild);
            
            expect(newMaster.uuid).to.beNil;
            expect(newChild.uuid).to.beNil;
            expect(newOtherChild.uuid).to.beNil;
            expect(newChildChild.uuid).to.beNil;
            
            NSLog(@"results: %@", results);
            NSLog(@"results2: %@", results2);
            
            NSCountedSet *set = [NSCountedSet setWithArray:results];
            expect(set.count).to.equal(2);
            
            NSCountedSet *set2 = [NSCountedSet setWithArray:results2];
            expect(set2.count).to.beInTheRangeOf(2, 3);
        });
        
        it(@"throws an exception when linking actors causes circular references", ^{
            [actors superviseWithId:@"master" creationBlock:^(NSObject **actor) {
                *actor = [TestActor new];
            }];
            [actors superviseWithId:@"child" creationBlock:^(NSObject **actor) {
                *actor = [TestActor new];
            }];
            [actors superviseWithId:@"otherChild" creationBlock:^(NSObject **actor) {
                *actor = [TestActor new];
            }];
            [actors superviseWithId:@"child.child" creationBlock:^(NSObject **actor) {
                *actor = [TestActor new];
            }];
            
            [actors linkActor:@"child" toParentActor:@"master"];
            [actors linkActor:@"otherChild" toParentActor:@"master"];
            [actors linkActor:@"child.child" toParentActor:@"child"];
            
            expect(^{
                [actors linkActor:@"master" toParentActor:@"child.child"];
            }).to.raise(TBAKException);
        });
    });
});

SpecEnd
