﻿/**
 * Authors: The D DBI project
 * Copyright: BSD license
 */
module dbi.sqlite.Sqlite;

private import tango.stdc.stringz : toDString = fromStringz, toCString = toStringz;
private import tango.util.log.Log;
    
public import dbi.model.Database;
import	dbi.Exception, dbi.model.Statement, dbi.util.Registry,
			dbi.util.StringWriter, dbi.util.Excerpt;

import dbi.sqlite.imp, dbi.sqlite.SqliteError;
import dbi.sqlite.SqliteStatement; 

import tango.core.Thread;
import Integer = tango.text.convert.Integer;

/**
 * An implementation of Database for use with SQLite databases.
 *
 * See_Also:
 *	Database is the interface that this provides an implementation of.
 */
class Sqlite : Database {
	
	private Logger logger;
	public:

	/**
	 * Create a new instance of Sqlite, but don't open a database.
	 */
	this () {
		stepFiber_ = new Fiber(&stepFiberRoutine,short.max);
		logger = Log.lookup("dbi.sqlite.Sqlite");
		debug logger.info("Sqlite lib version {}", toDString(sqlite3_libversion));
	}

	/**
	 * Create a new instance of Sqlite and open a database.
	 *
	 * See_Also:
	 *	connect
	 */
	this (char[] dbFile) {
		this();
		connect(dbFile);
	}
	
	~this() {
		close;
	}
	
	char[] type() { return "Sqlite"; }

	/**
	 * Open a SQLite database for use.
	 *
	 * Params:
	 *	dbfile = The name of the SQLite database to open.
	 *
	 * Throws:
	 *	DBIException if there was an error accessing the database.
	 *
	 * Examples:
	 *	---
	 *	auto db = new Sqlite();
	 *	db.connect("_test.db");
	 *	---
	 */
	void connect (char[] dbfile) {
		logger.trace("connecting: " ~ dbfile);
		if ((errorCode = sqlite3_open(toCString(dbfile), &sqlite_)) != SQLITE_OK) {
			throw new DBIException("Could not open or create " ~ dbfile, errorCode, specificToGeneral(errorCode));
		}
	}

	override void close () {
		logger.trace("closing database now");
		if (sqlite_ !is null) {
			while(lastSt) {
				lastSt.close;
				lastSt = lastSt.lastSt;
			}
			
			if ((errorCode = sqlite3_close(sqlite_)) != SQLITE_OK) {
				throw new DBIException(toDString(sqlite3_errmsg(sqlite_)), errorCode, specificToGeneral(errorCode));
			}
			sqlite_ = null;
		}
	}
	
	Statement doPrepare(char[] sql)
	{
		auto stmt = doPrepareRaw(sql);
		
		lastSt = new SqliteStatement(sqlite_, stmt, sql, lastSt);
		return lastSt;
	}
	
	private sqlite3_stmt* doPrepareRaw(char[] sql)
	{
		debug logger.trace("Preparing: {}", excerpt(sql_));
		char* errorMessage;
		sqlite3_stmt* stmt;
		if ((errorCode = sqlite3_prepare_v2(sqlite_, toCString(sql), cast(int)sql.length, &stmt, &errorMessage)) != SQLITE_OK) {
			throw new DBIException("sqlite3_prepare_v2 error: " ~ toDString(sqlite3_errmsg(sqlite_)), sql, errorCode, specificToGeneral(errorCode));
		}
		return stmt;
	}
	
	alias SqliteStatement StatementT;
	
	private SqliteStatement lastSt = null;

	ulong affectedRows () {
		return sqlite3_changes(sqlite_);
	}
	
	

/+	/**
	 * Get a list of all the table names.
	 *
	 * Returns:
	 *	An array of all the table names.
	 */
	char[][] getTableNames () {
		return getItemNames("table");
	}

	/**
	 * Get a list of all the view names.
	 *
	 * Returns:
	 *	An array of all the view names.
	 */
	char[][] getViewNames () {
		return getItemNames("view");
	}

	/**
	 * Get a list of all the index names.
	 *
	 * Returns:
	 *	An array of all the index names.
	 */
	char[][] getIndexNames () {
		return getItemNames("index");
	}

	/**
	 * Check if a view exists.
	 *
	 * Params:
	 *	name = Name of the view to check for the existance of.
	 *
	 * Returns:
	 *	true if it exists or false otherwise.
	 */
	bool hasView (char[] name) {
		return hasItem("view", name);
	}

	/**
	 * Check if an index exists.
	 *
	 * Params:
	 *	name = Name of the index to check for the existance of.
	 *
	 * Returns:
	 *	true if it exists or false otherwise.
	 */
	bool hasIndex (char[] name) {
		return hasItem("index", name);
	}+/
	
	void startTransaction()
	{
		execute("BEGIN");
	}
	
	void rollback()
	{
		execute("ROLLBACK");
	}
	
	void commit()
	{
		execute("COMMIT");
	}
	
	debug(DBITest) {
		override void doTests()
		{
			Stdout.formatln("Beginning Sqlite Tests");
			
			auto test = new SqliteTest(this);
			test.run;
			
			Stdout.formatln("Completed Sqlite Tests");
		}
	}

	bool hasTable (char[] name) {
		return hasItem("table", name);
	}
	
	/**
	 *
	 */
	bool hasItem(char[] type, char[] name) {
		query("SELECT name FROM sqlite_master WHERE type=? AND name=?",
							type, name);
		auto has = rowCount > 0 ? true : false;
		closeResult;
		return has;
	}
	
	bool moreResults()
	{
		return false;
	}
	
	bool nextResult()
	{
		return false;
	}
	
	bool validResult()
	{
		return lastRes_ == SQLITE_ROW ? true : false;
	}
	
	void closeResult()
	{
		while(stepFiber_.state != Fiber.State.TERM) {
			stepFiber_.call(true);
		}
		stepFiber_.reset;
	}
	
	ulong rowCount()
	{
		return sqlite3_data_count(stmt_);
	}
	
	ulong fieldCount()
	{
		return sqlite3_column_count(stmt_);
	}
	
	FieldInfo[] rowMetadata()
	{
		auto fieldCount = sqlite3_column_count(stmt_);
		FieldInfo[] fieldInfo;
		for(int i = 0; i < fieldCount; ++i)
		{
			FieldInfo info;
			
			info.name = toDString(sqlite3_column_name(stmt_, i));
			info.type = SqliteStatement.fromSqliteType(sqlite3_column_type(stmt_, i));
			
			fieldInfo ~= info;
		}
		
		return fieldInfo;
	}
	
	bool nextRow()
	{
		if(stepFiber_.state == Fiber.State.TERM) return false;
		stepFiber_.call(true);
		return lastRes_ == SQLITE_ROW ? true : false;
	}
	
	private const char[] OutOfSyncQueryErrorMsg =
		"Commands out of sync - cannot run a new sqlite "
		"query until you have finshed cycling through all result rows "
		"using fetch() or by calling closeResult() to close the current query.";
	
	void initQuery(in char[] sql, bool haveParams)
	{
		if(stepFiber_.state == Fiber.State.HOLD && sql_.length) {
			closeResult;
			stepFiber_.reset;
		}
		else if(stepFiber_.state == Fiber.State.TERM)  stepFiber_.reset;
		debug if(stepFiber_.state != Fiber.State.HOLD) throw new DBIException(OutOfSyncQueryErrorMsg,
				sql_,ErrorCode.OutOfSync);
		sql_ = sql;
		stepFiber_.call(true);
	}
	
	void doQuery()
	{
		if(stepFiber_.state != Fiber.State.HOLD)
			throw new DBIException(OutOfSyncQueryErrorMsg,
				sql_,ErrorCode.OutOfSync);		
		stepFiber_.call(true);
	}
	
	private void stepFiberRoutine()
	{
		bool checkRes() {
			debug logger.trace("Checking res {}", lastRes_);
			if(lastRes_ == SQLITE_DONE) {
				debug logger.trace("No more rows");
				return false;
			}
			else if(lastRes_ != SQLITE_ROW) {
				assert(false, "Error");
			}
			else {
				debug logger.trace("Have a row");
				return true;
			}
		}
		
		try
		{
			debug assert(stmt_ is null);
			debug assert(sql_ !is null);
			stmt_ = doPrepareRaw(sql_);
			assert(stmt_ !is null);
			numParams_ = sqlite3_bind_parameter_count(stmt_);
			curParamIdx_ = 0;
			Fiber.yield;
			curParamIdx_ = -1;
			debug logger.trace("Executing {}",excerpt(sql_));
			lastRes_ = sqlite3_step(stmt_);
			if(!checkRes) return;
			Fiber.yield;
			numFields_ = sqlite3_column_count(stmt_);
			Fiber.yield;
			while(lastRes_ == SQLITE_ROW) {
				assert(stmt_ !is null);
				lastRes_ = sqlite3_step(stmt_);
				if(!checkRes) return;
				Fiber.yield;
			}
		}
		catch(Exception ex)
		{
			debug logger.error("Caught exception in stepFiberRoutine {}", ex.toString);
			//throw ex;
			Fiber.yieldAndThrow(ex);
		}
		finally
		{
			debug logger.trace("Cleaning up after {}",excerpt(sql_));
			numFields_ = 0;
			if(stmt_ !is null) {
				debug logger.trace("Finalizing stmt_");
				sqlite3_finalize(stmt_);
				stmt_ = null;
			}
		}
	}
	
	ulong lastInsertID() in { assert(sqlite_ !is null); }
	body {
		return sqlite3_last_insert_rowid(sqlite_);
	}
	
	static BindType fromSqliteType(char[] str)
	{
		switch(str)
		{
		case "TEXT": return BindType.String;
		case "BLOB": return BindType.Binary;
		case "INTEGER": return BindType.Long;
		case "REAL": return BindType.Double;
		case "NONE":
		default:
			return BindType.Null;
		}
	}
	
	bool bindField(Type)(inout Type val, size_t idx)
	{
		debug logger.trace("Binding field of type {}, idx {}", Type.stringof, idx);
		if(stmt_ is null || lastRes_ != SQLITE_ROW || numFields_ <= idx) return false;
		SqliteStatement.bindT!(Type,false)(stmt_,val,idx);
		return true;
	}
	
	bool getField(inout bool val, size_t idx) { return bindField(val, idx); }    
	bool getField(inout ubyte val, size_t idx) { return bindField(val, idx); }
	bool getField(inout byte val, size_t idx) { return bindField(val, idx); }
	bool getField(inout ushort val, size_t idx) { return bindField(val, idx); }
	bool getField(inout short val, size_t idx) { return bindField(val, idx); }
	bool getField(inout uint val, size_t idx) { return bindField(val, idx); }
	bool getField(inout int val, size_t idx) { return bindField(val, idx); }
	bool getField(inout ulong val, size_t idx) { return bindField(val, idx); }
	bool getField(inout long val, size_t idx) { return bindField(val, idx); }
	bool getField(inout float val, size_t idx) { return bindField(val, idx); }
	bool getField(inout double val, size_t idx) { return bindField(val, idx); }
	bool getField(inout char[] val, size_t idx) { return bindField(val, idx); }
	bool getField(inout ubyte[] val, size_t idx) { return bindField(val, idx); }
	bool getField(inout Time val, size_t idx) { return bindField(val, idx); }
	bool getField(inout DateTime val, size_t idx) { return bindField(val, idx); }
	
	void setParamT(Type,bool Null = false)(Type val)
	{
		if(stmt_ is null || numParams_ <= curParamIdx_)
			throw new DBIException(
				"Param index " ~ Integer.toString(curParamIdx_) ~ " of type "
				~ Type.stringof ~ " out of bounds "
				"when binding sqlite param",sql_);
		if(curParamIdx_ < 0) {
			throw new DBIException(
				"Trying to bind parameter of type"
				~ Type.stringof ~ " to sqlite statement "
				"but this operation is out of sync - you can't do this right now. "
				"Please check the order of your statements.",sql_);
		}
		static if(Null) SqliteStatement.bindNull!(true)(stmt_,curParamIdx_);
		else SqliteStatement.bindT!(Type,true)(stmt_,val,curParamIdx_);
		++curParamIdx_;
	}
	
	void setParam(bool val) { setParamT(val); }
	void setParam(ubyte val) { setParamT(val); }
	void setParam(byte val) { setParamT(val); }
	void setParam(ushort val) { setParamT(val); }
	void setParam(short val) { setParamT(val); }
	void setParam(uint val) { setParamT(val); }
	void setParam(int val) { setParamT(val); }
	void setParam(ulong val) { setParamT(val); }
	void setParam(long val) { setParamT(val); }
	void setParam(float val) { setParamT(val); }
	void setParam(double val) { setParamT(val); }
	void setParam(char[] val) { setParamT(val); }
	void setParam(ubyte[] val) { setParamT(val); }
	void setParam(Time val) { setParamT(val); }
	void setParam(DateTime val) { setParamT(val); }
	void setParamNull() { setParamT!(void*,true)(null); }
	
	bool enabled(DbiFeature feature) { return false; }
	
	void initInsert(char[] tablename, char[][] fields)
	{
		if(writer_ is null) writer_ = new SqlStringWriter;
		initQuery(sqlGen.makeInsertSql(writer_,tablename,fields),true);
	}
	
	void initUpdate(char[] tablename, char[][] fields, char[] where)
	{
		if(writer_ is null) writer_ = new SqlStringWriter;
		initQuery(sqlGen.makeUpdateSql(writer_,tablename,where,fields),true);
	}
	
	void initSelect(char[] tablename, char[][] fields, char[] where, bool haveParams)
	{
		if(writer_ is null) writer_ = new SqlStringWriter;
		else writer_.reset;
		writer_("SELECT ");
		foreach(field; fields)
		{
			writer_(`"`,field,`",`);
		}
		writer_.correct(' ');
		writer_(`FROM "`,tablename,`" `);
		writer_(where);
		debug logger.trace("Wrote select sql {}", writer_.get);
		initQuery(writer_.get,haveParams);
	}
	
	void initRemove(char[] tablename, char[] where, bool haveParams)
	{
		if(writer_ is null) writer_ = new SqlStringWriter;
		else writer_.reset;
		writer_(`DELETE FROM "`, tablename, `" `, where);
		debug logger.trace("Wrote delete sql {}", writer_.get);
		initQuery(writer_.get,haveParams);
	}
	
	bool startWritingMultipleStatements()
	{
		return false;
	}
	
	bool isWritingMultipleStatements()
	{
		return false;
	}
	
	char[] escapeString(in char[] str, char[] dst = null)
	{
		size_t count = 0;
		size_t len = str.length;
		// Maximum length needed if every char is to be quoted
		if(dst.length < len * 2) dst.length = len * 2;

		for (size_t i = 0; i < len; i++) {
			switch (str[i]) {
				case '"':
				case '\'':
				case '\\':
					dst[count++] = '\\';
					break;
				default:
					break;
			}
			dst[count++] = str[i];
		}

		return dst[0 .. count];
	}
	
	ColumnInfo[] getTableInfo(char[] tablename)
	{
		query(`PRAGMA table_info("` ~ tablename ~ `")`);
		
		ColumnInfo[] info;
		while(nextRow) {
			char[] tmp;
			ColumnInfo col;
			getField(col.name,1);
			getField(tmp,2);
			col.type = fromSqliteType(tmp);
			getField(tmp,3); if(tmp != "0") col.notNull = true;
			getField(tmp,5); if(tmp == "1") col.primaryKey = true;
			info ~= col;
		}
		
		return info;
	}
	
	override SqlGenerator getSqlGenerator()
	{
    	return SqliteSqlGenerator.inst;
	}
	
	sqlite3* handle() { return sqlite_; }
	
	SqlStringWriter buffer() { return writer_; }
	void buffer(SqlStringWriter writer) { writer_ = writer; }
	
	private:
		sqlite3* 		sqlite_;
		sqlite3_stmt* 	stmt_;
		char[] 			sql_;
		int 			errorCode;
		int 			lastRes_;
		Fiber 			stepFiber_;
		int 			numFields_;
		int 			numParams_;
		int 			curParamIdx_;
		SqlStringWriter writer_;
}

private class SqliteSqlGenerator : SqlGenerator
{
	static this() { inst = new SqliteSqlGenerator; }
	static SqliteSqlGenerator inst;
	
	char[] toNativeType(ColumnInfo info)
	{
		char[] result;
		with(BindType)
		{
			switch(info.type)
			{
			case Bool:
			case Byte:
			case Short:
			case Int:
			case Long:
			case UByte:
			case UShort:
			case UInt:
			case ULong:
				result = "INTEGER";
				break;
			case Float:
			case Double:
				result = "REAL";
				break;
			case String:
			case Time:
			case DateTime:
				result = "TEXT";
				break;
			case Binary:
				result = "BLOB";
				break;
			case Null:
				result = "NONE";
				break;
			default:
				debug assert(false, "Unhandled column type"); //TODO more detailed information;
				break;
			}
		}
		return result;
	}
	
	char[] makeColumnDef(ColumnInfo info, ColumnInfo[] columnInfo)
	{
		char[] res = toNativeType(info);
		
		bool multiPKey = false;
		foreach(col; columnInfo) if(col.primaryKey && col.name != info.name) {
			multiPKey = true;
			break;
		}
		
		if(info.notNull)	res ~= " NOT NULL"; else res ~= " NULL";
		if(info.primaryKey && !multiPKey) res ~= " PRIMARY KEY";
		if(info.autoIncrement) res ~= " AUTOINCREMENT";
		
		return res;
	}
}

private class SqliteRegister : IRegisterable {
	
	static this() {
		debug(DBITest) Stdout("Attempting to register Sqlite in Registry").newline;
		registerDatabase(new SqliteRegister());
	}
	
	private Logger logger;
	
	this() {
		logger = Log.getLogger("dbi.sqlite");
	}
	
	public char[] getPrefix() {
		return "sqlite";
	}
	
	public Database getInstance(char[] url) {
		logger.trace("creating Sqlite database: " ~ url);
		return cast(Database)new Sqlite(url);
	}
}

debug(DBITest) {

import tango.io.Stdout;

class SqliteTest : DBTest
{
	this(Sqlite db)
	{ super(db); }
	
	void dbTests()
	{
		auto ti = db.getTableInfo("dbi_test"); 
		assert(ti);
		assert(ti.length == 15);
		
		assert(ti[0].name == "id");
		assert(ti[0].type == BindType.Long);
		assert(ti[0].notNull == true);
		assert(ti[0].primaryKey == true);
		
		assert(ti[1].name == "UByte");
		assert(ti[1].type == BindType.Long);
		assert(ti[1].notNull == false);
		assert(ti[1].primaryKey == false);
		
		assert(ti[2].name == "Byte");
		assert(ti[2].type == BindType.Long);
		assert(ti[2].notNull == false);
		assert(ti[2].primaryKey == false);
		
		assert(ti[3].name == "UShort");
		assert(ti[3].type == BindType.Long);
		assert(ti[3].notNull == false);
		assert(ti[3].primaryKey == false);
		
		assert(ti[4].name == "Short");
		assert(ti[4].type == BindType.Long);
		assert(ti[4].notNull == false);
		assert(ti[4].primaryKey == false);
		
		assert(ti[5].name == "UInt");
		assert(ti[5].type == BindType.Long);
		assert(ti[5].notNull == false);
		assert(ti[5].primaryKey == false);
		
		assert(ti[6].name == "Int");
		assert(ti[6].type == BindType.Long);
		assert(ti[6].notNull == false);
		assert(ti[6].primaryKey == false);
		
		assert(ti[7].name == "ULong");
		assert(ti[7].type == BindType.Long);
		assert(ti[7].notNull == false);
		assert(ti[7].primaryKey == false);
		
		assert(ti[8].name == "Long");
		assert(ti[8].type == BindType.Long);
		assert(ti[8].notNull == false);
		assert(ti[8].primaryKey == false);
		
		
		assert(ti[9].name == "Float");
		assert(ti[9].type == BindType.Double);
		assert(ti[9].notNull == false);
		assert(ti[9].primaryKey == false);


		assert(ti[10].name == "Double");
		assert(ti[10].type == BindType.Double);
		assert(ti[10].notNull == false);
		assert(ti[10].primaryKey == false);
		
		assert(ti[11].name == "String");
		assert(ti[11].type == BindType.String);
		assert(ti[11].notNull == true);
		assert(ti[11].primaryKey == false);
		
		assert(ti[12].name == "Binary");
		assert(ti[12].type == BindType.Binary);
		assert(ti[12].notNull == false);
		assert(ti[12].primaryKey == false);
		
		assert(ti[13].name == "DateTime");
		assert(ti[13].type == BindType.String);
		assert(ti[13].notNull == false);
		assert(ti[13].primaryKey == false);
		
		assert(ti[14].name == "Time");
		assert(ti[14].type == BindType.String);
		assert(ti[14].notNull == false);
		assert(ti[14].primaryKey == false);
	}
}


unittest {
    void s1 (char[] s) {
        tango.io.Stdout.Stdout(s).newline();
    }

    void s2 (char[] s) {
        tango.io.Stdout.Stdout("   ..." ~ s).newline();
    }

	s1("dbi.sqlite.Sqlite:");
	Sqlite db = new Sqlite();
	s2("connect");
	db.connect("test.sqlite");

	s2("query");

	db.test;
	
/+	Result res = db.query("SELECT * FROM test");
	assert (res !is null);

	s2("fetchRow");
	Row row = res.fetchRow();
	assert (row !is null);
	assert (row.getFieldIndex("id") == 0);
	assert (row.getFieldIndex("name") == 1);
	assert (row.getFieldIndex("dateofbirth") == 2);
	assert (row.get("id") == "1");
	assert (row.get("name") == "John Doe");
	assert (row.get("dateofbirth") == "1970-01-01");
	assert (row.getFieldType(1) == SQLITE_TEXT);
	assert (row.getFieldDecl(1) == "char(40)");
	res.finish();

	s2("prepare");
	Statement stmt = db.prepare("SELECT * FROM test WHERE id = ?");
	stmt.bind(1, "1");
	res = stmt.query();
	row = res.fetchRow();
	res.finish();
	assert (row[0] == "1");

	s2("fetchOne");
	row = db.queryFetchOne("SELECT * FROM test");
	assert (row[0] == "1");

	s2("execute(INSERT)");
	db.execute("INSERT INTO test VALUES (2, 'Jane Doe', '2000-12-31')");

	s2("execute(DELETE via prepare statement)");
	stmt = db.prepare("DELETE FROM test WHERE id=?");
	stmt.bind(1, "2");
	stmt.execute();

	s2("getChanges");
	assert (db.getChanges() == 1);

	s2("getTableNames, getViewNames, getIndexNames");
	assert (db.getTableNames().length == 1);
	assert (db.getIndexNames().length == 1);
	assert (db.getViewNames().length == 0);

	s2("hasTable, hasView, hasIndex");
	assert (db.hasTable("test") == true);
	assert (db.hasTable("doesnotexist") == false);
	assert (db.hasIndex("doesnotexist") == false);
	assert (db.hasView("doesnotexist") == false);
+/
	s2("close");
	db.close();
}
}
