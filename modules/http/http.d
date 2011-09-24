module http;

import croc.api;
import croc.ex_bind;
import lib.fcgi;
import lib.util;

import tango.io.Stdout;

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
		superPush(t, getRequest(t).params);
		newGlobal(t, "params");
		
		return 0;
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

		
		uword init(CrocThread* t)
		{
			CreateClass(t, "Cookie", (CreateClass* c)
			{
				c.method("constructor", &constructor);
				c.method("opField", &opField);
				c.method("opFieldAssign", &opFieldAssign);
				
			});
			newFunction(t, &BasicClassAllocator!(1, 0), "Cookie.allocator");
			setAllocator(t, -2);
			
			setWrappedClass(t, typeid(Cookie));
			newGlobal(t, "Cookie");
			
			return 0;
		}
}