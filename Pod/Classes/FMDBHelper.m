//
//  FMDBHelper.m
//  FMDBHelper
//
//  Created by 李京城 on 15/3/10.
//  Copyright (c) 2015年 李京城. All rights reserved.
//

#import "FMDBHelper.h"
#import "FMDB.h"

@implementation FMDBHelper

static NSString *dbName = @"";

+ (void)setDataBaseName:(NSString *)name {
    NSAssert(name, @"name cannot be nil!");
    dbName = name;
    if(![[NSFileManager defaultManager] fileExistsAtPath:[self dbPath]]) {
        NSString *bundlePath = [[NSBundle mainBundle] pathForResource:dbName ofType:nil];
        if ([[NSFileManager defaultManager] fileExistsAtPath:bundlePath]) {
            [[NSFileManager defaultManager] copyItemAtPath:bundlePath toPath:[self dbPath] error:nil];
        } else {
            NSAssert(NO, @"%@ does not exist!", dbName);
        }
    }
}

+ (BOOL)createTable:(NSString *)sql {
    return [self executeUpdate:sql args:nil];
}

+ (BOOL)dropTable:(NSString *)tableName {
    NSString *sql = [NSString stringWithFormat:@"DROP TABLE IF EXISTS %@", tableName];
    return [self executeUpdate:sql args:nil];
}


#pragma mark - insert

+ (BOOL)insert:(NSString *)sql {
    NSAssert(sql, @"sql cannot be nil!");
    
    return [self executeUpdate:sql args:nil];
}

+ (BOOL)insertObject:(NSObject *)obj {
    NSAssert(obj, @"obj cannot be nil!");
    
    return [self insert:[[obj class] tableName] keyValues:[obj keyValues]];
}

+ (BOOL)insert:(NSString *)table keyValues:(NSDictionary *)keyValues {
    NSAssert(table && keyValues, @"table or keyValues cannot be nil!");
    
    return [self insert:table keyValues:keyValues replace:YES];
}

+ (BOOL)insert:(NSString *)table keyValues:(NSDictionary *)keyValues replace:(BOOL)replace {
    NSAssert(table && keyValues, @"table or keyValues cannot be nil!");
    
    NSMutableArray *columns = [NSMutableArray array];
    NSMutableArray *values = [NSMutableArray array];
    NSMutableArray *placeholder = [NSMutableArray array];
    
    [keyValues enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        if (obj && ![obj isEqual:[NSNull null]]) {
            [columns addObject:key];
            [values addObject:obj];
            [placeholder addObject:@"?"];
        }
    }];
    
    NSString *sql = [[NSString alloc] initWithFormat:@"INSERT%@ INTO %@ (%@) VALUES (%@)", replace ? @" OR REPLACE" : @"", table, [columns componentsJoinedByString:@","], [placeholder componentsJoinedByString:@","]];
    
    return [self executeUpdate:sql args:values];
}

#pragma mark - update

+ (BOOL)update:(NSString *)sql {
    NSAssert(sql, @"sql cannot be nil!");
    return [self executeUpdate:sql args:nil];
}

+ (BOOL)updateObject:(NSObject *)obj {
    NSAssert(obj, @"obj cannot be nil!");
    
    return [self update:[[obj class] tableName] keyValues:[obj keyValues]];
}

+ (BOOL)update:(NSString *)table keyValues:(NSDictionary *)keyValues {
    NSAssert(table && keyValues, @"table or keyValues cannot be nil!");
    NSAssert(keyValues[identifier], @"keyValues[@\"%@\"] cannot be nil!", identifier);
    
    return [self update:table keyValues:keyValues where:[NSString stringWithFormat:@"%@='%@'", identifier, keyValues[identifier]]];
}

+ (BOOL)update:(NSString *)table keyValues:(NSDictionary *)keyValues where:(NSString *)where {
    NSAssert(table && keyValues && where, @"table,keyValues,where can't be nil!");
    
    NSMutableArray *settings = [NSMutableArray array];
    NSMutableArray *values = [NSMutableArray array];
    
    [keyValues enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        if (obj && ![obj isEqual:[NSNull null]]) {
            [settings addObject:[NSString stringWithFormat:@"%@=?", key]];
            [values addObject:obj];
        }
    }];
    
    NSString *sql = [[NSString alloc] initWithFormat:@"UPDATE %@ SET %@ WHERE %@", table, [settings componentsJoinedByString:@","], where];
    
    return [self executeUpdate:sql args:values];
}

#pragma mark - remove

+ (BOOL)remove:(NSString *)table {
    NSAssert(table, @"table cannot be nil!");
    
    return [self remove:table where:@"1=1"];
}

+ (BOOL)removeObject:(NSObject *)obj {
    NSAssert(obj, @"obj cannot be nil!");
    
    return [self removeById:obj.ID from:[[obj class] tableName]];
}

+ (BOOL)removeById:(NSString *)id_ from:(NSString *)table {
    NSAssert(id_ && table, @"id_ or table cannot be nil!");
    
    return [self remove:table where:[NSString stringWithFormat:@"%@='%@'", identifier, id_]];
}

+ (BOOL)remove:(NSString *)table where:(NSString *)where {
    NSAssert(table && where, @"table or where cannot be nil!");
    
    NSString *sql = [[NSString alloc] initWithFormat:@"DELETE FROM %@ WHERE %@", table, where];
    
    return [self executeUpdate:sql args:nil];
}


#pragma mark - query

+ (NSMutableArray *)query:(NSString *)table {
    NSAssert(table, @"table cannot be nil!");
    
    return [self query:table where:@"1=1", nil];
}

+ (NSDictionary *)queryById:(NSString *)id_ from:(NSString *)table {
    NSAssert(id_ && table, @"id_ or table cannot be nil!");
    
    NSMutableArray *result = [self query:table where:[NSString stringWithFormat:@"%@=?", identifier], id_, nil];
    
    return (result.count > 0) ? result.firstObject : nil;
}

+ (NSMutableArray *)query:(NSString *)table where:(NSString *)where, ... {
    NSAssert(table && where, @"table or where cannot be nil!");
    
    NSMutableArray *result = [[NSMutableArray alloc] initWithCapacity:10];
    
    va_list args;
    va_start(args, where);
    
    FMDatabase *db = [FMDatabase databaseWithPath:[self dbPath]];
    
    if ([db open]) {
        FMResultSet *rs = [db executeQuery:[NSString stringWithFormat:@"SELECT * FROM %@ WHERE %@", table, where] withVAList:args];
        while ([rs next]) {
            [result addObject:[rs resultDictionary]];
        }
        
        [db close];
    }
    
    db = nil;
    
    va_end(args);
    
    return result;
}

+ (NSInteger)totalRowOfTable:(NSString *)table {
    NSAssert(table, @"table cannot be nil!");
    
    return [self totalRowOfTable:table where:@"1=1"];
}

+ (double)queryResult:(NSString *)where
{
    NSAssert(where, @"table or where cannot be nil!");
    double sum = 0;
    FMDatabase *db = [FMDatabase databaseWithPath:[self dbPath]];
    if ([db open]) {
        NSString *sql = [NSString stringWithFormat:@"select SUM(results) as sum from result WHERE %@",where];

        FMResultSet *rs = [db executeQuery:sql];
        if ([rs next]) {
            sum = [rs doubleForColumn:@"sum"];
        }

        [db close];
    }

    db = nil;
    return sum;

}
+ (NSInteger)totalRowOfTable:(NSString *)table where:(NSString *)where {
    NSAssert(table && where, @"table or where cannot be nil!");
    
    NSInteger totalRow = 0;
    
    FMDatabase *db = [FMDatabase databaseWithPath:[self dbPath]];
    
    if ([db open]) {
        FMResultSet *rs = [db executeQuery:[NSString stringWithFormat:@"SELECT COUNT(%@) totalRow FROM %@ WHERE %@", identifier, table, where]];
        if ([rs next]) {
            totalRow = [[rs resultDictionary][@"totalRow"] integerValue];
        }
    
        [db close];
    }
    
    db = nil;
    
    return totalRow;
}


+ (double)sumFromTable:(NSString *)table row:(NSString *)name where:(NSString *)where
{
    NSAssert(table && name && where, @"table or where cannot be nil!");
    double sum = 0;
    FMDatabase *db = [FMDatabase databaseWithPath:[self dbPath]];
    if ([db open]) {
        NSString *sql = [NSString stringWithFormat:@"select SUM(%@) as sum from %@ WHERE %@",name,table,where];

        FMResultSet *rs = [db executeQuery:sql];
        if ([rs next]) {
            sum = [rs doubleForColumn:@"sum"];
        }

        [db close];
    }

    db = nil;

    return sum;
}

#pragma mark - batch

+ (BOOL)executeBatch:(NSArray *)sqls useTransaction:(BOOL)useTransaction {
    NSAssert(sqls, @"sqls cannot be nil!");
    
    __block BOOL success = YES;
    
    FMDatabaseQueue *queue = [FMDatabaseQueue databaseQueueWithPath:[self dbPath]];
    
    if (useTransaction) {
        [queue inTransaction:^(FMDatabase *db, BOOL *rollback) {
            for (NSString *sql in sqls) {
                if (![db executeUpdate:sql]) {
                    *rollback = YES;
                    success = NO;
                    break;
                }
            }
        }];
    } else {
        [queue inDatabase:^(FMDatabase *db) {
            for (NSString *sql in sqls) {
                [db executeUpdate:sql];
            }
        }];
    }
    
    return success;
}

#pragma mark - private method

+ (BOOL)executeUpdate:(NSString *)sql args:(NSArray *)args {
    BOOL success = NO;
    
    FMDatabase *db = [FMDatabase databaseWithPath:[self dbPath]];
    if ([db open]) {
        success = [db executeUpdate:sql withArgumentsInArray:args];

        [db close];
    }
    
    db = nil;
    
    return success;
}

+ (NSString *)dbPath {
    NSAssert(dbName, @"dbName cannot be nil!");
    
    return [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject] stringByAppendingPathComponent:dbName];
}

+ (BOOL) isTableOK:(NSString *)tableName
{
    FMDatabase *db = [FMDatabase databaseWithPath:[self dbPath]];
    FMResultSet *rs = [db executeQuery:@"select count(*) as 'count' from result where type ='table' and name = ?", tableName];
    while ([rs next])
        {
        // just print out what we've got in a number of formats.
        NSInteger count = [rs intForColumn:@"count"];
        NSLog(@"isTableOK %ld", (long)count);

        if (0 == count)
            {
            return NO;
            }
        else
            {
            return YES;
            }
        }

    return NO;
}

+ (void)addColumn:(NSString *)columnName
{
    FMDatabase *db = [FMDatabase databaseWithPath:[self dbPath]];
    [db open];
    if (![db columnExists:columnName inTableWithName:@"result"]) {
        NSString *alertStr = [NSString stringWithFormat:@"ALTER TABLE result ADD %@ INTEGER",columnName];
        BOOL worked = [db executeUpdate:alertStr];
        if(worked){
            NSLog(@"插入成功");
            [db close];
        }else{
            [db close];
            NSLog(@"插入失败");
        }
    }
}
@end
