module http;

import croc.api;
import croc.ex_bind;
import lib.fcgi;
import lib.util;

import tango.io.Stdout;
import tango.io.device.Array;

import tango.net.http.HttpCookies;

void http_init(CrocThread* ct)
{	
	makeModule(ct, "http", &HttpModule.init);
}

struct HttpModule
{
static:
	uword init(CrocThread* t)
	{
		superPush(t, getRequest(t).env);
		newGlobal(t, "env");
		CookieObj.init(t);
		parseCookies(t);
		
		return 0;
	}
	
	private void parseCookies(CrocThread* t)
	{
		auto p = getRequest(t).env;
		auto tab = newTable(t);
		
		if("HTTP_COOKIE" in p)
		{
			auto stack = new CookieStack(10);
			auto parser = new CookieParser(stack);
			parser.parse(p["HTTP_COOKIE"]);
			
			foreach(cookie; stack)
			{
				superPush(t, cookie);
				fielda(t, tab, cookie.name, true);
			}
		}
		
		newGlobal(t, "cookies");
	}
}

struct CookieObj
{
	static:
		private Cookie getThis(CrocThread* t)
		{
			return cast(Cookie)getNativeObj(t, getExtraVal(t, 0, 0));
		}
		
		uword constructor(CrocThread* t)
		{
			auto numParams = stackSize(t) - 1;
			checkInstParam(t, 0, "Cookie");
			Cookie inst;
			
			if(numParams == 0)
			{
				inst = new Cookie();
			}
			else if(numParams == 2)
			{
				char[] name = checkStringParam(t, 1);
				char[] value = checkStringParam(t, 2);
				inst = new Cookie(name, value);
			}
			
			if(inst is null) throwStdException(t, "Exception", "No such constructor");
			
			pushNativeObj(t, inst);
			setExtraVal(t, 0, 0);
			setWrappedInstance(t, inst, 0);
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
				case "path":
					pushString(t, inst.path);
					break;
				case "value":
					pushString(t, inst.value);
					break;
				case "domain":
					pushString(t, inst.domain);
					break;
				case "comment":
					pushString(t, inst.comment);
					break;
				case "secure":
					pushBool(t, inst.secure);
					break;
				case "maxAge":
					pushInt(t, inst.maxAge);
					break;
				case "version":
					pushInt(t, inst.vrsn);
					break;
			}
			
			return 1;
		}

		uword opFieldAssign(CrocThread* t)
		{
			auto inst = getThis(t);
			char[] fieldName = checkStringParam(t, 1);
			switch(fieldName)
			{
				default:
					throwStdException(t, "FieldException", "Attempting to access nonexistent field '{}' from type Cookie", fieldName);
				case "name":
					inst.name = checkStringParam(t, 2);
					break;
				case "path":
					inst.path = checkStringParam(t, 2);
					break;
				case "value":
					inst.value = checkStringParam(t, 2);
					break;
				case "domain":
					inst.domain = checkStringParam(t, 2);
					break;
				case "comment":
					inst.comment = checkStringParam(t, 2);
					break;
				case "secure":
					inst.secure = checkBoolParam(t, 2);
					break;
				case "maxAge":
					inst.maxAge = checkIntParam(t, 2);
					break;
				case "version":
					inst.vrsn = checkIntParam(t, 2);
					break;
			}
			
			return 0;
		}
		
		uword toString(CrocThread* t)
		{
			auto a = new Array(64, 64);
			auto inst = getThis(t);
			
			inst.produce(&a.write);
			
			pushString(t, cast(char[])a.slice);
			
			return 1;
		}
		
		uword init(CrocThread* t)
		{
			CreateClass(t, "Cookie", (CreateClass* c)
			{
				c.method("constructor", &constructor);
				c.method("opField", &opField);
				c.method("opFieldAssign", &opFieldAssign);
				c.method("toString", &toString);
				
			});
			newFunction(t, &BasicClassAllocator!(1, 0), "Cookie.allocator");
			setAllocator(t, -2);
			
			setWrappedClass(t, typeid(Cookie));
			newGlobal(t, "Cookie");
			
			return 0;
		}
}