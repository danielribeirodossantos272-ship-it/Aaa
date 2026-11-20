#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import "FLEXReplicaRuntimeBridge.h"

NSArray<NSString *> *FLEXReplicaCopyRuntimeClassNames(void) {
    unsigned int count = 0;
    Class *classes = objc_copyClassList(&count);
    if (classes == NULL) {
        return @[];
    }

    NSMutableArray<NSString *> *names = [NSMutableArray arrayWithCapacity:count];
    for (unsigned int index = 0; index < count; index++) {
        const char *rawName = class_getName(classes[index]);
        if (rawName == NULL) {
            continue;
        }
        NSString *name = [NSString stringWithUTF8String:rawName];
        if (name != nil) {
            [names addObject:name];
        }
    }
    free(classes);
    [names sortUsingSelector:@selector(compare:)];
    return [names copy];
}
