module db;

import tango.time.Time;
import Integer = tango.text.convert.Integer;

import croc.api;
import croc.api_debug;
import croc.ex_bind;
import croc.stdlib_time;

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
		auto meta = inst.rowMetadata();
		
		for(uint i = 0; i < inst.fieldCount; i++)
		{
			pushField(t, inst, i, meta[i]);
		}
		return inst.fieldCount;
	}
	
	uword fetchTable(CrocThread* t)
	{
		auto inst = getThis(t);
		auto meta = inst.rowMetadata();
		auto slot = getUpval(t, 0);
		clearTable(t, slot);
		
		for(uint i = 0; i < inst.fieldCount; i++)
		{
			pushField(t, inst, i, meta[i]);
			fielda(t, slot, meta[i].name);
		}
		
		return 1;
	}
	
	uword fetchArray(CrocThread* t)
	{
		auto inst = getThis(t);
		auto meta = inst.rowMetadata();
		auto slot = getUpval(t, 0);
		lenai(t, slot, inst.fieldCount);
		
		for(uint i = 0; i < inst.fieldCount; i++)
		{
			pushField(t, inst, i, meta[i]);
			idxai(t, slot, i);
		}
	
		return 1;
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
			
			newTable(t);	//pushing upvalue table
			c.method("fetchTable", &fetchTable, 1);
			
			newArray(t, 0);	//pushing upvalue array
			c.method("fetchArray", &fetchArray, 1);
			
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

	void pushField(CrocThread* t, Result inst, uint i, FieldInfo info)
	{
		switch(info.type)
		{
			case BindType.Null:
				pushNull(t);
				break;
			case BindType.Bool:
				bool field;
				inst.getField(field, i);
				pushBool(t, field);
				break;
			case BindType.UShort:
			case BindType.Short:
				short field;
				inst.getField(field, i);
				pushInt(t, field);
				break;
			case BindType.UInt:
			case BindType.Int:
				int field;
				inst.getField(field, i);
				pushInt(t, field);
				break;
			case BindType.ULong:
			case BindType.Long:
				long field;
				inst.getField(field, i);
				pushInt(t, field);
				break;
		/*		
			case BindType.UByte:		
		*/
			case BindType.Float:
				float field;
				inst.getField(field, i);
				pushFloat(t, field);
				break;
			case BindType.Double:
				double field;
				inst.getField(field, i);
				pushFloat(t, field);
				break;
			case BindType.String:
				char[] field;
				inst.getField(field, i);
				pushString(t, field);
				break;
			//case Binary:  push memblock here
			case BindType.Time:
				Time field;
				inst.getField(field, i);
				pushInt(t, (field - Time.epoch1970).seconds);
				break;
			case BindType.DateTime:
				DateTime field;
				inst.getField(field, i);
				uword slot = newTable(t);
				TimeLib.DateTimeToTable(t, field, slot);
				break;
			default:
				throwException(t, "Unsupported BindType: " ~ info.name ~ "=" ~ Integer.toString(info.type));
		}
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