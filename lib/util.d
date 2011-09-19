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