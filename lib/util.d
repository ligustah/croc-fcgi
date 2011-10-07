module lib.util;

import croc.api;
import croc.ex;

import lib.fcgi;

public void pushRequest(CrocThread* t, FCGI_Request r)
{
	pushNativeObj(t, r);
	setRegistryVar(t, "fcgi.request");
}

public FCGI_Request getRequest(CrocThread* t)
{
	return cast(FCGI_Request) getNativeObj(t, getRegistryVar(t, "fcgi.request"));
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

