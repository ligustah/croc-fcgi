module db;

import tango.time.Time;
import Integer = tango.text.convert.Integer;

import croc.api;
import croc.api_debug;
import croc.ex_bind;
import croc.stdlib_time;

import dbi.DBI;
import dbi.Exception;
import dbi.ErrorCode;
import dbi.model.Database;
import dbi.util.VirtualPrepare;

public void db_init(CrocThread* t)
{
	makeModule(t, "db", &DBModule.init);
}

struct DBModule
{
static:
	uword init(CrocThread* t)
	{
		void sink(char[] msg)
		{
			Stdout(msg).flush;
		}
		
		try
		{
			BindTypeEnum.init(t);
			FieldInfoObj.init(t);
			ColumnInfoObj.init(t);
			ResultObj.init(t);
			DatabaseObj.init(t);
		}catch(CrocException e)
		{
			catchException(t);
			pop(t);
			if(e.info)
				e.info.writeOut(&sink);
		}
		
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
		throwStdException(t, "Exception", "Cannot created instances of this class!");
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
		
		superPush(t, info);
		
		/*
		
		foreach(row; info)
		{
			pushString(t, row.name);
		}
		newArrayFromStack(t, info.length);
		
		*/
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
			case BindType.UByte:
				ubyte field;
				inst.getField(field, i);
				pushInt(t, field);
				break;
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
			case BindType.Binary:
				ubyte[] data;
				inst.getField(data, i);
				memblockFromDArray(t, data);
				break;
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
				throwStdException(t, "Exception", "Unsupported BindType: " ~ info.name ~ "=" ~ Integer.toString(info.type));
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
	
	void setParam(CrocThread* t, word slot)
	{
		auto inst = getThis(t);
		auto type = .type(t, slot);
		
		with(CrocValue.Type)
		{
			switch(type)
			{
				case Null:
					inst.setParamNull();
					break;
				case Bool:
					inst.setParam(getBool(t, slot));
					break;
				case Int:
					inst.setParam(getInt(t, slot));
					break;
				case Float:
					inst.setParam(getFloat(t, slot));
					break;
				case Char:
					char[1] buf;
					buf[0] = getChar(t, slot);
					inst.setParam(buf);
					break;
				case String:
					inst.setParam(getString(t, slot));
					break;
				/*
				case Table:
				case Array:
				*/
				case Memblock:
					inst.setParam(cast(ubyte[])getMemblockData(t, slot));
					break;
				default:
					pushToString(t, slot);
					throwStdException(t, "NotImplementedException", "Cannot pass value {} at slot {}", getString(t, -1), slot);
					break;

			}
		}
	}
	
	void setParams(CrocThread* t, word start)
	{
		auto numParams = stackSize(t) - 1;
		for(word slot = start; slot < numParams; slot++)
		{
			setParam(t, slot);
		}
	}
	
	uword setParam(CrocThread* t)
	{
		checkAnyParam(t, 1);
		setParam(t, 1);
		return 0;
	}
	
	uword constructor(CrocThread* t)
	{
		checkInstParam(t, 0, "Database");
		char[] url = checkStringParam(t, 1);
		Database inst;
		
		try
		{
			inst = getDatabaseForURL(url);
		}catch(DBIException dbie)
		{
			throwStdException(t, "Exception", "{} - {}:{}", dbie.toString, dbie.getSpecificCode, toString(dbie.getErrorCode));
		}
		
		pushNativeObj(t, inst);
		setExtraVal(t, 0, 0);
		setWrappedInstance(t, inst, 0);
		
		return 0;
	}
	
	uword query(CrocThread* t)
	{
		auto numParams = stackSize(t) - 1;
		auto inst = getThis(t);
		char[] qry = checkStringParam(t, 1);
		
		if(numParams == 1)
		{
			inst.query(qry);
		}
		else
		{
			inst.initQuery(qry, true);
			setParams(t, 2);
			inst.doQuery();
		}
		
		return 0; //maybe return rowCount here?
	}
	
	uword insert(CrocThread* t)
	{
		auto numParams = stackSize(t) - 1;
		auto inst = getThis(t);
		char[] table = checkStringParam(t, 1);
		char[][] fields = superGet!(char[][])(t, 2);
		
		auto remaining = numParams - 2;
		
		if(fields.length != remaining)
			throwStdException(t, "ApiError", "Passed params don't match fields");
		
		inst.initInsert(table, fields);
		setParams(t, 3);
		inst.doQuery();
		
		return 0; //maybe return lastInsertID here?
	}
	
	uword update(CrocThread* t)
	{
		auto numParams = stackSize(t) - 1;
		auto inst = getThis(t);
		char[] table = checkStringParam(t, 1);
		char[][] fields = superGet!(char[][])(t, 2);
		char[] where = checkStringParam(t, 3);
		
		auto remaining = numParams - 3;
		
		if(fields.length + getParamIndices(where).length != remaining)
			throwStdException(t, "ApiError", "Passed params don't match fields");
		
		inst.initUpdate(table, fields, where);
		setParams(t, 4);
		inst.doQuery();
		
		return 0; //maybe return affectedRows here?
	}	
	
	uword select(CrocThread* t)
	{
		auto numParams = stackSize(t) - 1;
		auto inst = getThis(t);
		char[] table = checkStringParam(t, 1);
		char[][] fields = superGet!(char[][])(t, 2);
		char[] where = checkStringParam(t, 3);
		
		auto remaining = numParams - 3;
		
		inst.initSelect(table, fields, where, remaining > 0);
		setParams(t, 4);
		inst.doQuery();
		
		return 0; //maybe return rowCount here?
	}
		
	uword remove(CrocThread* t)
	{
		auto numParams = stackSize(t) - 1;
		auto inst = getThis(t);
		char[] table = checkStringParam(t, 1);
		char[] where = checkStringParam(t, 2);
		
		auto remaining = numParams - 2;
		
		inst.initRemove(table, where, remaining > 0);
		setParams(t, 3);
		inst.doQuery();
	
		return 0; //maybe return affectedRows here
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
	
	uword getTableInfo(CrocThread* t)
	{
		auto inst = getThis(t);
		char[] table = checkStringParam(t, 1);
		safeCode(t, superPush(t, inst.getTableInfo(table)));
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
		bool haveParams = checkBoolParam(t, 3);
		inst.initRemove(table, where, haveParams);
		return 0;
	}
	
	uword doQuery(CrocThread* t)
	{
		auto inst = getThis(t);
		inst.doQuery();
		return 0;
	}
	
	void init(CrocThread* t)
	{
		CreateClass(t, "Database", "Result", (CreateClass* c)
		{
			c.method("constructor", &constructor);
			c.method("query", &query);
			c.method("insert", &insert);
			c.method("update", &update);
			c.method("select", &select);
			c.method("remove", &remove);
			c.method("lastInsertID", &lastInsertID);
			c.method("close", &close);
			c.method("escapeString", &escapeString);
			c.method("startTransaction", &startTransaction);
			c.method("begin", &startTransaction);
			c.method("rollback", &rollback);
			c.method("commit", &commit);
			c.method("hasTable", &hasTable);
			c.method("getTableInfo", &getTableInfo);
			c.method("type", &type);
			c.method("initQuery", &initQuery);
			c.method("initInsert", &initInsert);
			c.method("initUpdate", &initUpdate);
			c.method("initSelect", &initSelect);
			c.method("initRemove", &initRemove);
			c.method("doQuery", &doQuery);
			c.method("setParam", &setParam);
		});
		
		newFunction(t, &BasicClassAllocator!(1, 0), "Database.allocator");
		setAllocator(t, -2);
		
		setWrappedClass(t, typeid(Database));
		newGlobal(t, "Database");
	}
}

struct FieldInfoObj
{
static:
	private FieldInfo* getThis(CrocThread* t)
	{
		return &(cast(StructWrapper!(FieldInfo))getNativeObj(t, getExtraVal(t, 0, 0))).inst;
	}
	
	uword constructor(CrocThread* t)
	{
		throwStdException(t, "NotImplementedException", "not implemented");
		
		return 0;
	}
	
	uword opField(CrocThread* t)
	{
		auto inst = getThis(t);
		char[] fieldName = checkStringParam(t, 1);
		switch(fieldName)
		{
			default:
				throwStdException(t, "FieldException", "Attempting to access nonexistent field '{}' from type Cookie", fieldName);
			case "name":
				pushString(t, inst.name);
				break;
			case "type":
				pushInt(t, cast(ubyte)inst.type);
				break;
		}
		return 1;
	}
	
	uword opFieldAssign(CrocThread* t)
	{
		throwStdException(t, "RuntimeException", "FieldInfo is read-only!");
		
		return 0;
	}
	
	void init(CrocThread* t)
	{
		CreateClass(t, "FieldInfo", (CreateClass* c)
		{
			c.method("constructor", &constructor);
			c.method("opFieldAssign", &opFieldAssign);
			c.method("opField", &opField);
		});
		
		newFunction(t, &BasicClassAllocator!(1, 0), "FieldInfo.allocator");
		setAllocator(t, -2);
		
		setWrappedClass(t, typeid(FieldInfo));
		newGlobal(t, "FieldInfo");
	}
}

struct ColumnInfoObj
{
static:
	private ColumnInfo* getThis(CrocThread* t)
	{
		return &(cast(StructWrapper!(ColumnInfo))getNativeObj(t, getExtraVal(t, 0, 0))).inst;
	}
	
	uword constructor(CrocThread* t)
	{
		throwStdException(t, "NotImplementedException", "Not implemented");
		
		return 0;
	}
	
	uword opField(CrocThread* t)
	{
		auto inst = getThis(t);
		char[] fieldName = checkStringParam(t, 1);
		switch(fieldName)
		{
			default:
				throwStdException(t, "FieldException", "Attempting to access nonexistent field '{}' from type ColumnInfo", fieldName);
			case "name":
				pushString(t, inst.name);
				break;
			case "type":
				pushInt(t, cast(ubyte)inst.type);
				break;
			case "notNull":
				pushBool(t, inst.notNull);
				break;
			case "autoIncrement":
				pushBool(t, inst.autoIncrement);
				break;
			case "primaryKey":
				pushBool(t, inst.primaryKey);
				break;
			case "limit":
				pushInt(t, inst.limit);
				break;
			case "uniqueKey":
				pushBool(t, inst.uniqueKey);
				break;
		}
		return 1;
	}
	
	uword opFieldAssign(CrocThread* t)
	{
		throwStdException(t, "RuntimeException", "ColumnInfo is read-only!");
		
		return 0;
	}
	
	void init(CrocThread* t)
	{
		CreateClass(t, "ColumnInfo", (CreateClass* c)
		{
			c.method("constructor", &constructor);
			c.method("opField", &opField);
			c.method("opFieldAssign", &opFieldAssign);
		});
		
		newFunction(t, &BasicClassAllocator!(1, 0), "ColumInfo.allocator");
		setAllocator(t, -2);
		
		setWrappedClass(t, typeid(ColumnInfo));
		newGlobal(t, "ColumnInfo");
	}
}

import tango.io.Stdout;

struct BindTypeEnum
{
static:
	private char[][BindType] typeToString;
	uword toString(CrocThread* t)
	{
		BindType type = cast(BindType)checkIntParam(t, 1);
		if((type in typeToString) !is null)
			pushString(t, typeToString[type]);
		else pushString(t, "invalid");
		return 1;
	}
	
	void init(CrocThread* t)
	{
		newNamespace(t, "BindType");
		
		pushInt(t, cast(ubyte)BindType.Null); fielda(t, -2, "Null");
		pushInt(t, cast(ubyte)BindType.Bool); fielda(t, -2, "Bool");
		pushInt(t, cast(ubyte)BindType.Byte); fielda(t, -2, "Byte");
		pushInt(t, cast(ubyte)BindType.Short); fielda(t, -2, "Short");
		pushInt(t, cast(ubyte)BindType.Int); fielda(t, -2, "Int");
		pushInt(t, cast(ubyte)BindType.Long); fielda(t, -2, "Long");
		pushInt(t, cast(ubyte)BindType.UByte); fielda(t, -2, "UByte");
		pushInt(t, cast(ubyte)BindType.UShort); fielda(t, -2, "UShort");
		pushInt(t, cast(ubyte)BindType.UInt); fielda(t, -2, "UInt");
		pushInt(t, cast(ubyte)BindType.ULong); fielda(t, -2, "ULong");
		pushInt(t, cast(ubyte)BindType.Float); fielda(t, -2, "Float");
		pushInt(t, cast(ubyte)BindType.Double); fielda(t, -2, "Double");
		pushInt(t, cast(ubyte)BindType.String); fielda(t, -2, "String");
		pushInt(t, cast(ubyte)BindType.Binary); fielda(t, -2, "Binary");
		pushInt(t, cast(ubyte)BindType.Time); fielda(t, -2, "Time");
		pushInt(t, cast(ubyte)BindType.DateTime); fielda(t, -2, "DateTime");
		
		newFunction(t, &toString, "BindType.toString", 0);
		fielda(t, -2, "toString");
		
		newGlobal(t, "BindType");
		
		with(BindType)
		{
			typeToString[Null] = "Null";
			typeToString[Bool] = "Bool";
			typeToString[Byte] = "Byte";
			typeToString[Short] = "Short";
			typeToString[Int] = "Int";
			typeToString[Long] = "Long";
			typeToString[UByte] = "UByte";
			typeToString[UShort] = "UShort";
			typeToString[UInt] = "UInt";
			typeToString[ULong] = "ULong";
			typeToString[Float] = "Float";
			typeToString[Double] = "Double";
			typeToString[String] = "String";
			typeToString[Binary] = "Binary";
			typeToString[Time] = "Time";
			typeToString[DateTime] = "DateTime";
		}
	}
}