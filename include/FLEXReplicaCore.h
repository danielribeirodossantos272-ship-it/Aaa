#ifndef FLEXREPLICACORE_H
#define FLEXREPLICACORE_H

#ifdef __cplusplus
extern "C" {
#endif

/// Installs the draggable floating control when the host app has an active UI scene.
void FLEXReplicaInstallFloatingButton(void);

/// Presents the inspector panel manually after the host app has an active UI scene.
void FLEXReplicaShowMenu(void);

#ifdef __cplusplus
}
#endif

#endif /* FLEXREPLICACORE_H */
