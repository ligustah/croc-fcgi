module db;

import lib.util;
import lib.fcgi;

import croc.api;
import croc.api_debug;
import croc.ex_bind;

import dbi.DBI;
import dbi.model.Database;

public void db_init(CrocThread* t)
{
	makeModule(t, "db", &DBModule.init);
}

struct DBModule
{
static:
	uword init(CrocThread* t)
	{
		ResultObj.init(t);
		DatabaseObj.init(t);
		
		return 0;
	}
}

struct ResultObj
{
static:
	Result getThis(CrocThread* t)
	{
		return cast(Result)getNativeObj(t, getExtraVal(t, 0, 0));
	}
	
	uword constructor(CrocThread* t)
	{
		throwException(t, "Cannot created instances of this class!");
		return 0;
	}
	
	uword nextRow(CrocThread* t)
	{
		auto inst = getThis(t);
		pushBool(t, inst.nextRow());
		return 1;
	}
	
	uword fetch(CrocThread* t)
	{
		auto inst = getThis(t);
		
		return 0;
	}
	
	uword rowCount(CrocThread* t)
	{
		auto inst = getThis(t);
		pushInt(t, inst.rowCount);
		return 1;
	}
	
	uword fieldCount(CrocThread* t)
	{
		auto inst = getThis(t);
		pushInt(t, inst.fieldCount);
		return 1;
	}
	
	uword affectedRows(CrocThread* t)
	{
		auto inst = getThis(t);
		pushInt(t, inst.affectedRows);
		return 1;
	}
	
	uword validResult(CrocThread* t)
	{
		auto inst = getThis(t);
		pushBool(t, inst.validResult);
		return 1;
	}
	
	uword closeResult(CrocThread* t)
	{
		auto inst = getThis(t);
		inst.closeResult();
		return 0;
	}
	
	uword moreResults(CrocThread* t)
	{
		auto inst = getThis(t);
		pushBool(t, inst.moreResults);
		return 1;
	}
	
	uword nextResult(CrocThread* t)
	{
		auto inst = getThis(t);
		pushBool(t, inst.nextResult);
		return 1;
	}
	
	uword rowMetadata(CrocThread* t)
	{
		auto inst = getThis(t);
		auto info = inst.rowMetadata();
		
		foreach(row; info)
		{
			pushString(t, row.name);
		}
		newArrayFromStack(t, info.length);
		return 1;
	}
	
	void init(CrocThread* t)
	{
		CreateClass(t, "Result", (CreateClass* c)
		{
			c.method("constructor", &constructor);
			c.method("nextRow", &nextRow);
			c.method("fetch", &fetch);
			c.method("rowCount", &rowCount);
			c.method("fieldCount", &fieldCount);
			c.method("affectedRows", &affectedRows);
			c.method("validResult", &validResult);
			c.method("closeResult", &closeResult);
			c.method("moreResults", &moreResults);
			c.method("nextResult", &nextResult);
			c.method("rowMetadata", &rowMetadata);
		});
		
		newFunction(t, &BasicClassAllocator!(1, 0), "Result.allocator");
		setAllocator(t, -2);
		
		setWrappedClass(t, typeid(Result));
		newGlobal(t, "Result");
	}
}

struct DatabaseObj
{
static:
	private Database getThis(CrocThread* t)
	{
		return cast(Database)getNativeObj(t, getExtraVal(t, 0, 0));
	}
	
	uword constructor(CrocThread* t)
	{
		checkInstParam(t, 0, "Database");
		char[] url = checkStringParam(t, 1);
		Database inst;
		
		inst = safeCode(t, getDatabaseForURL(url));
		
		pushNativeObj(t, inst);
		setExtraVal(t, 0, 0);
		setWrappedInstance(t, inst, 0);
		
		return 0;
	}
	
	uword query(CrocThread* t)
	{
		auto inst = getThis(t);
		char[] qry = checkStringParam(t, 1);
		
		inst.query(qry);
		
		return 0;
	}
	
	uword lastInsertID(CrocThread* t)
	{
		auto inst = getThis(t);
		pushInt(t, inst.lastInsertID);
		return 1;
	}
	
	uword close(CrocThread* t)
	{
		auto inst = getThis(t);
		inst.close();
		return 0;
	}
	
	uword escapeString(CrocThread* t)
	{
		auto inst = getThis(t);
		char[] str = checkStringParam(t, 1);
		pushString(t, inst.escapeString(str));
		return 1;
	}
	
	uword startTransaction(CrocThread* t)
	{
		auto inst = getThis(t);
		inst.startTransaction();
		return 0;
	}
	
	uword commit(CrocThread* t)
	{
		auto inst = getThis(t);
		inst.commit();
		return 0;
	}
	
	uword rollback(CrocThread* t)
	{
		auto inst = getThis(t);
		inst.rollback();
		return 0;
	}
	
	uword hasTable(CrocThread* t)
	{
		auto inst = getThis(t);
		char[] table = checkStringParam(t, 1);
		pushBool(t, inst.hasTable(table));
		return 1;
	}
	
	uword type(CrocThread* t)
	{
		auto inst = getThis(t);
		pushString(t, inst.type);
		return 1;
	}
	
	uword initQuery(CrocThread* t)
	{
		auto inst = getThis(t);
		char[] sql = checkStringParam(t, 1);
		bool haveParams = checkBoolParam(t, 2);
		inst.initQuery(sql, haveParams);
		return 0;
	}
	
	uword initInsert(CrocThread* t)
	{
		auto inst = getThis(t);
		char[] table = checkStringParam(t, 1);
		char[][] fields = superGet!(char[][])(t, 2);
		inst.initInsert(table, fields);
		return 0;
	}
	
	uword initUpdate(CrocThread* t)
	{
		auto inst = getThis(t);
		char[] table = checkStringParam(t, 1);
		char[][] fields = superGet!(char[][])(t, 2);
		char[] where = checkStringParam(t, 3);
		inst.initUpdate(table, fields, where);
		return 0;
	}
	
	uword initSelect(CrocThread* t)
	{
		auto inst = getThis(t);
		char[] table = checkStringParam(t, 1);
		char[][] fields = superGet!(char[][])(t, 2);
		char[] where = checkStringParam(t, 3);
		bool haveParams = checkBoolParam(t, 4);
		inst.initSelect(table, fields,  where, haveParams);
		return 0;
	}
	
	uword initRemove(CrocThread* t)
	{
		auto inst = getThis(t);
		char[] table = checkStringParam(t, 1);
		char[] where = checkStringParam(t, 2);
		bool haveParams = superGet!(bool)(t, 3);
		inst.initRemove(table, where, haveParams);
		return 0;
	}
	
	void init(CrocThread* t)
	{
		CreateClass(t, "Database", "Result", (CreateClass* c)
		{
			c.method("constructor", &constructor);
			c.method("query", &query);
			c.method("lastInsertID", &lastInsertID);
			c.method("close", &close);
			c.method("escapeString", &escapeString);
			c.method("startTransaction", &startTransaction);
			c.method("begin", &startTransaction);
			c.method("rollback", &rollback);
			c.method("commit", &commit);
			c.method("hasTable", &hasTable);
			c.method("type", &type);
			c.method("initQuery", &initQuery);
			c.method("initInsert", &initInsert);
			c.method("initUpdate", &initUpdate);
			c.method("initSelect", &initSelect);
			c.method("initRemove", &initRemove);
		});
		
		newFunction(t, &BasicClassAllocator!(1, 0), "Database.allocator");
		setAllocator(t, -2);
		
		setWrappedClass(t, typeid(Database));
		newGlobal(t, "Database");
	}
}