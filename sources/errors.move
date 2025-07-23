module weissfarming::errors;

// === Errors ===
public fun ENotAllowedPool(): u64 {0}
public fun ERewardPoolAlreadyExist(): u64 {1}
public fun ENotUpgrade(): u64 {2}
public fun EUnauthorized(): u64 {3}
public fun EUnclaimedRewards(): u64 {4}
public fun EInvalidRewardPool(): u64 {5}
public fun EInvalidHolderPositionCap(): u64 {6}
public fun EPackageVersionError(): u64 {7}
public fun ENoRewardsToClaim(): u64 {8}