#ifndef FLEXREPLICA_RUNTIME_BRIDGE_H
#define FLEXREPLICA_RUNTIME_BRIDGE_H

#import <Foundation/Foundation.h>

FOUNDATION_EXPORT NSArray<NSString *> *FLEXReplicaCopyRuntimeClassNames(void);
FOUNDATION_EXPORT BOOL FLEXReplicaTryGetObjectValue(id _Nullable object,
                                                   NSString * _Nonnull key,
                                                   id _Nullable __autoreleasing * _Nonnull valueOut);
FOUNDATION_EXPORT BOOL FLEXReplicaTrySetObjectValue(id _Nullable object,
                                                   NSString * _Nonnull key,
                                                   id _Nullable value);

#endif /* FLEXREPLICA_RUNTIME_BRIDGE_H */
