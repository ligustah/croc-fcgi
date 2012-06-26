module lib.util;

import croc.api;
import croc.ex;

import lib.fcgi;

import tango.io.FilePath;

public void pushRequest(CrocThread* t, FCGI_Request r)
{
	pushNativeObj(t, r);
	setRegistryVar(t, "fcgi.request");
}

public FCGI_Request getRequest(CrocThread* t)
{
	auto r =  cast(FCGI_Request) getNativeObj(t, getRegistryVar(t, "fcgi.request"));
	pop(t);
	return r;
}

public Type getRegistryObject(Type)(CrocThread* t, char[] key)
{
	auto o =  cast(Type) getNativeObj(t, getRegistryVar(t, key));
	pop(t);
	return o;
}

public void pushRegistryObject(CrocThread* t, char[] key, Object value)
{
	pushNativeObj(t, value);
	setRegistryVar(t, key);
}

public bool hasRegistryVar(CrocThread* t, char[] key)
{
	getRegistry(t);
	pushString(t, key);
	bool has = opin(t, -1, -2);
	
	//remove registry and string
	pop(t, 2);
	
	return has;
}

version(Windows)
{
	import tango.sys.win32.UserGdi;
	import tango.sys.win32.Types;
	
	char[] getExePath()
	{
		char[MAX_PATH] path;
		
		DWORD len = GetModuleFileNameA(NULL, path.ptr, path.length);
		
		if(len)
		{
			return path[0 .. len].dup;
		}
		else
		{
			throw new Exception("GetModuleFileName failed");
		}
	}
} else version(linux)
{
	import tango.sys.linux.linux;
	
	char[] getExePath()
	{
		char[] link = "/proc/self/exe\0"; //null terminated
		char[256] path;
		
		size_t len = readlink(link.ptr, path.ptr, path.length);
		
		if(len != -1)
		{
			return path[0 .. len];
		}
		else
		{
			throw new Exception("readlink failed");
		}
	}
}
else
{
	static assert(0, "getExePath not supported on this platform");
}

FilePath getExeDir()
{
	return FilePath(getExePath()).pop();
}