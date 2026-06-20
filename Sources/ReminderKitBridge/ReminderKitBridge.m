#import "ReminderKitBridge.h"

#import <dlfcn.h>

NSString *const RKReminderKitErrorDomain = @"dev.remindctl.ReminderKit";

@interface NSObject (RKReminderKitPrivate)
+ (id)objectIDWithURL:(NSURL *)url;
- (id)initWithStore:(id)store;
- (id)fetchReminderWithObjectID:(id)objectID error:(NSError **)error;
- (id)updateReminder:(id)reminder;
- (BOOL)saveSynchronouslyWithError:(NSError **)error;
- (id)list;
- (BOOL)isShared;
- (NSArray *)sharees;
- (NSString *)currentUserShareParticipantID;
- (NSString *)displayName;
- (NSString *)address;
- (id)remObjectID;
- (NSUUID *)uuid;
- (id)assignmentContext;
- (void)removeAllAssignments;
- (id)addAssignmentWithAssigneeID:(id)assigneeID originatorID:(id)originatorID status:(NSInteger)status;
@end

static NSError *RKError(NSInteger code, NSString *message) {
  return [NSError errorWithDomain:RKReminderKitErrorDomain
                             code:code
                         userInfo:@{NSLocalizedDescriptionKey: message}];
}

static BOOL RKLoadFramework(NSError **error) {
  static void *handle;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    handle = dlopen("/System/Library/PrivateFrameworks/ReminderKit.framework/ReminderKit", RTLD_NOW);
  });
  if (handle) return YES;
  if (error) {
    const char *message = dlerror();
    *error = RKError(1, message ? [NSString stringWithUTF8String:message] : @"ReminderKit is unavailable");
  }
  return NO;
}

static NSString *RKTrimmedIdentifier(NSString *value) {
  NSString *trimmed = [value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  NSURL *url = [NSURL URLWithString:trimmed];
  if (url.scheme.length && url.lastPathComponent.length) return url.lastPathComponent;
  return trimmed;
}

static id RKObjectID(NSString *entity, NSString *identifier, NSError **error) {
  Class objectIDClass = NSClassFromString(@"REMObjectID");
  SEL selector = @selector(objectIDWithURL:);
  if (!objectIDClass || ![objectIDClass respondsToSelector:selector]) {
    if (error) *error = RKError(2, @"This macOS version does not expose ReminderKit object IDs");
    return nil;
  }

  NSString *clean = RKTrimmedIdentifier(identifier);
  NSString *urlString = [NSString stringWithFormat:@"x-apple-reminderkit://%@/%@", entity, clean];
  id objectID = [objectIDClass objectIDWithURL:[NSURL URLWithString:urlString]];
  if (!objectID && error) *error = RKError(3, [NSString stringWithFormat:@"Invalid %@ identifier: %@", entity, identifier]);
  return objectID;
}

static NSString *RKString(id object, SEL selector) {
  if (!object || ![object respondsToSelector:selector]) return nil;
  id (*implementation)(id, SEL) = (void *)[object methodForSelector:selector];
  id value = implementation(object, selector);
  return [value isKindOfClass:[NSString class]] ? value : nil;
}

static NSString *RKShareeIdentifier(id sharee) {
  if (![sharee respondsToSelector:@selector(remObjectID)]) return nil;
  id objectID = [sharee remObjectID];
  if (![objectID respondsToSelector:@selector(uuid)]) return nil;
  NSUUID *uuid = [objectID uuid];
  return [uuid isKindOfClass:[NSUUID class]] ? uuid.UUIDString : nil;
}

static BOOL RKMatches(NSString *candidate, NSString *query) {
  if (!candidate.length) return NO;
  NSStringCompareOptions options = NSCaseInsensitiveSearch | NSDiacriticInsensitiveSearch;
  return [candidate compare:query options:options] == NSOrderedSame;
}

static id RKResolveSharee(NSArray *sharees, NSString *query, NSError **error) {
  NSMutableArray *matches = [NSMutableArray array];
  NSMutableArray<NSString *> *available = [NSMutableArray array];
  NSString *trimmed = [query stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

  for (id sharee in sharees) {
    NSString *name = RKString(sharee, @selector(displayName));
    NSString *address = RKString(sharee, @selector(address));
    NSString *identifier = RKShareeIdentifier(sharee);
    NSString *label = name.length && address.length ? [NSString stringWithFormat:@"%@ <%@>", name, address] : (name ?: address);
    if (label.length) [available addObject:label];
    if (RKMatches(name, trimmed) || RKMatches(address, trimmed) || RKMatches(identifier, trimmed)) {
      [matches addObject:sharee];
    }
  }

  if (matches.count == 1) return matches.firstObject;
  if (error) {
    if (matches.count > 1) {
      *error = RKError(4, [NSString stringWithFormat:@"Assignee \"%@\" is ambiguous; use the exact email address", query]);
    } else {
      NSString *suffix = available.count ? [NSString stringWithFormat:@" Available participants: %@.", [available componentsJoinedByString:@", "]] : @"";
      *error = RKError(5, [NSString stringWithFormat:@"Assignee \"%@\" is not a participant in this shared list.%@", query, suffix]);
    }
  }
  return nil;
}

NSDictionary<NSString *, id> *RKSetReminderAssignment(
  NSString *reminderIdentifier,
  NSString *assignee,
  NSError **error
) {
  @try {
    if (!RKLoadFramework(error)) return nil;

    Class storeClass = NSClassFromString(@"REMStore");
    Class saveClass = NSClassFromString(@"REMSaveRequest");
    if (!storeClass || !saveClass) {
      if (error) *error = RKError(6, @"This macOS version does not expose the required ReminderKit classes");
      return nil;
    }

    id reminderObjectID = RKObjectID(@"REMCDReminder", reminderIdentifier, error);
    if (!reminderObjectID) return nil;

    id store = [[storeClass alloc] init];
    if (![store respondsToSelector:@selector(fetchReminderWithObjectID:error:)]) {
      if (error) *error = RKError(7, @"This macOS version does not support ReminderKit reminder lookup");
      return nil;
    }
    NSError *fetchError = nil;
    id reminder = [store fetchReminderWithObjectID:reminderObjectID error:&fetchError];
    if (!reminder) {
      if (error) *error = fetchError ?: RKError(8, @"ReminderKit could not find the reminder");
      return nil;
    }

    id list = [reminder respondsToSelector:@selector(list)] ? [reminder list] : nil;
    if (!list || ![list respondsToSelector:@selector(isShared)] || ![list isShared]) {
      if (error) *error = RKError(9, @"Assignments are only supported for reminders in shared lists");
      return nil;
    }

    id save = [[saveClass alloc] initWithStore:store];
    if (![save respondsToSelector:@selector(updateReminder:)]) {
      if (error) *error = RKError(10, @"This macOS version does not support ReminderKit reminder updates");
      return nil;
    }
    id change = [save updateReminder:reminder];
    id context = [change respondsToSelector:@selector(assignmentContext)] ? [change assignmentContext] : nil;
    if (!context || ![context respondsToSelector:@selector(removeAllAssignments)]) {
      if (error) *error = RKError(11, @"This macOS version does not support native reminder assignment");
      return nil;
    }

    NSMutableDictionary *result = [@{
      @"reminderId": RKTrimmedIdentifier(reminderIdentifier),
      @"cleared": @(assignee == nil),
    } mutableCopy];
    [context removeAllAssignments];

    if (assignee != nil) {
      NSArray *sharees = [list respondsToSelector:@selector(sharees)] ? [list sharees] : nil;
      NSString *originatorIdentifier = RKString(list, @selector(currentUserShareParticipantID));
      if (![sharees isKindOfClass:[NSArray class]] || !originatorIdentifier.length) {
        if (error) *error = RKError(12, @"Could not read shared-list participants from ReminderKit");
        return nil;
      }

      id sharee = RKResolveSharee(sharees, assignee, error);
      if (!sharee) return nil;
      NSString *assigneeIdentifier = RKShareeIdentifier(sharee);
      if (!assigneeIdentifier.length) {
        if (error) *error = RKError(13, @"The selected participant has no ReminderKit identifier");
        return nil;
      }

      id assigneeObjectID = RKObjectID(@"REMCDSharee", assigneeIdentifier, error);
      id originatorObjectID = RKObjectID(@"REMCDSharee", originatorIdentifier, error);
      if (!assigneeObjectID || !originatorObjectID) return nil;
      if (![context respondsToSelector:@selector(addAssignmentWithAssigneeID:originatorID:status:)]) {
        if (error) *error = RKError(14, @"This macOS version cannot create native reminder assignments");
        return nil;
      }
      id assignment = [context addAssignmentWithAssigneeID:assigneeObjectID originatorID:originatorObjectID status:1];
      if (!assignment) {
        if (error) *error = RKError(15, @"ReminderKit did not create the assignment");
        return nil;
      }

      NSString *name = RKString(sharee, @selector(displayName));
      NSString *address = RKString(sharee, @selector(address));
      result[@"assigneeId"] = assigneeIdentifier;
      if (name.length) result[@"assigneeName"] = name;
      if (address.length) result[@"assigneeAddress"] = address;
    }

    if (![save respondsToSelector:@selector(saveSynchronouslyWithError:)]) {
      if (error) *error = RKError(16, @"This macOS version cannot save ReminderKit changes");
      return nil;
    }
    NSError *saveError = nil;
    if (![save saveSynchronouslyWithError:&saveError]) {
      if (error) *error = saveError ?: RKError(17, @"ReminderKit could not save the assignment");
      return nil;
    }
    return result;
  } @catch (NSException *exception) {
    if (error) {
      NSString *message = [NSString stringWithFormat:@"ReminderKit assignment failed: %@", exception.reason ?: exception.name];
      *error = RKError(18, message);
    }
    return nil;
  }
}
