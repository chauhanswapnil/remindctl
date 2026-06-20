#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString *const RKReminderKitErrorDomain;

/// Sets a native Apple Reminders assignment. A nil assignee clears it.
FOUNDATION_EXPORT NSDictionary<NSString *, id> * _Nullable RKSetReminderAssignment(
  NSString *reminderIdentifier,
  NSString * _Nullable assignee,
  NSError **error
);

/// Lists participants who can be assigned a reminder in its shared list.
FOUNDATION_EXPORT NSArray<NSDictionary<NSString *, id> *> * _Nullable RKListReminderAssignees(
  NSString *reminderIdentifier,
  NSError **error
);

NS_ASSUME_NONNULL_END
