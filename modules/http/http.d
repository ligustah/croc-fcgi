module http;

import croc.api;
import croc.ex_bind;
import lib.fcgi;
import lib.util;

import tango.io.Stdout;
import tango.io.device.Array;

import tango.net.http.HttpCookies;
import tango.net.http.HttpHeaders;
import tango.net.http.HttpConst;

void http_init(CrocThread* t)
{	
	makeModule(t, "http", &HttpModule.init);
}

struct HttpModule
{
static:
	uword addCookie(CrocThread* t)
	{
		auto numParams = stackSize(t) - 1;
		Cookie c;
		if(numParams == 1)
		{
			checkInstParam(t, 1, "Cookie");
			c = superGet!(Cookie)(t, 1);
		}
		else if(numParams == 2)
		{
			char[] name = checkStringParam(t, 1);
			char[] value = checkStringParam(t, 2);
			c = new Cookie(name, value);
		}
		
		if(c is null)	throwStdException(t, "ParamTypeError", "need an instance of Cookie or two strings");
		
		auto req = getRequest(t);
		
		req.addCookie(c);
		
		return 0;
	}
	
	uword addHeader(CrocThread* t)
	{
		char[] headerName = checkStringParam(t, 1);
		char[] value = checkStringParam(t, 2);		
		auto req = getRequest(t);
		
		req.headers.add(HttpHeaderName(headerName), value);
		return 0;
	}
	
	uword setResponseCode(CrocThread* t)
	{
		int code = checkIntParam(t, 1);		
		auto req = getRequest(t);
		
		req.setResponseCode(cast(HttpResponseCode)code);
		return 0;
	}
	
	uword redirect(CrocThread* t)
	{
		char[] url = checkStringParam(t, 1);
		auto req = getRequest(t);
		
		req.setResponseCode(HttpResponseCode.Found);
		req.headers.add(HttpHeader.Location, url);
		
		return 0;
	}

	uword init(CrocThread* t)
	{
		superPush(t, getRequest(t).env);   newGlobal(t, "env");
		CookieObj.init(t);
		getCookies(t);
		HttpEnums.init(t);
		
		newFunction(t, &addCookie, "addCookie", 0);   				newGlobal(t, "addCookie");
		newFunction(t, &addHeader, "addHeader", 0);  				newGlobal(t, "addHeader");
		newFunction(t, &setResponseCode, "setResponseCode", 0);		newGlobal(t, "setResponseCode");
		newFunction(t, &redirect, "redirect", 0);					newGlobal(t, "redirect");
		
		return 0;
	}
	
	private void getCookies(CrocThread* t)
	{
		auto c = getRequest(t).cookies;
		auto tab = newTable(t);
		
		foreach(name, cookie; c)
		{
			superPush(t, cookie);
			fielda(t, tab, name, true);
		}
		
		newGlobal(t, "cookies");
	}
}

struct HttpEnums
{
static:
	void init(CrocThread* t)
	{
		header(t);
		responseCode(t);
	}
	
	void header(CrocThread* t)
	{
		newNamespace(t, "header");
		
		pushString(t, HttpHeader.Accept.value); fielda(t, -2, "Accept");
		pushString(t, HttpHeader.AcceptCharset.value); fielda(t, -2, "AcceptCharset");
		pushString(t, HttpHeader.AcceptEncoding.value); fielda(t, -2, "AcceptEncoding");
		pushString(t, HttpHeader.AcceptLanguage.value); fielda(t, -2, "AcceptLanguage");
		pushString(t, HttpHeader.AcceptRanges.value); fielda(t, -2, "AcceptRanges");
		pushString(t, HttpHeader.Age.value); fielda(t, -2, "Age");
		pushString(t, HttpHeader.Allow.value); fielda(t, -2, "Allow");
		pushString(t, HttpHeader.Authorization.value); fielda(t, -2, "Authorization");
		pushString(t, HttpHeader.CacheControl.value); fielda(t, -2, "CacheControl");
		pushString(t, HttpHeader.Connection.value); fielda(t, -2, "Connection");
		pushString(t, HttpHeader.ContentEncoding.value); fielda(t, -2, "ContentEncoding");
		pushString(t, HttpHeader.ContentLanguage.value); fielda(t, -2, "ContentLanguage");
		pushString(t, HttpHeader.ContentLength.value); fielda(t, -2, "ContentLength");
		pushString(t, HttpHeader.ContentLocation.value); fielda(t, -2, "ContentLocation");
		pushString(t, HttpHeader.ContentRange.value); fielda(t, -2, "ContentRange");
		pushString(t, HttpHeader.ContentType.value); fielda(t, -2, "ContentType");
		pushString(t, HttpHeader.Cookie.value); fielda(t, -2, "Cookie");
		pushString(t, HttpHeader.Date.value); fielda(t, -2, "Date");
		pushString(t, HttpHeader.ETag.value); fielda(t, -2, "ETag");
		pushString(t, HttpHeader.Expect.value); fielda(t, -2, "Expect");
		pushString(t, HttpHeader.Expires.value); fielda(t, -2, "Expires");
		pushString(t, HttpHeader.From.value); fielda(t, -2, "From");
		pushString(t, HttpHeader.Host.value); fielda(t, -2, "Host");
		pushString(t, HttpHeader.Identity.value); fielda(t, -2, "Identity");
		pushString(t, HttpHeader.IfMatch.value); fielda(t, -2, "IfMatch");
		pushString(t, HttpHeader.IfModifiedSince.value); fielda(t, -2, "IfModifiedSince");
		pushString(t, HttpHeader.IfNoneMatch.value); fielda(t, -2, "IfNoneMatch");
		pushString(t, HttpHeader.IfRange.value); fielda(t, -2, "IfRange");
		pushString(t, HttpHeader.IfUnmodifiedSince.value); fielda(t, -2, "IfUnmodifiedSince");
		pushString(t, HttpHeader.KeepAlive.value); fielda(t, -2, "KeepAlive");
		pushString(t, HttpHeader.LastModified.value); fielda(t, -2, "LastModified");
		pushString(t, HttpHeader.Location.value); fielda(t, -2, "Location");
		pushString(t, HttpHeader.MaxForwards.value); fielda(t, -2, "MaxForwards");
		pushString(t, HttpHeader.MimeVersion.value); fielda(t, -2, "MimeVersion");
		pushString(t, HttpHeader.Pragma.value); fielda(t, -2, "Pragma");
		pushString(t, HttpHeader.ProxyAuthenticate.value); fielda(t, -2, "ProxyAuthenticate");
		pushString(t, HttpHeader.ProxyConnection.value); fielda(t, -2, "ProxyConnection");
		pushString(t, HttpHeader.Range.value); fielda(t, -2, "Range");
		pushString(t, HttpHeader.Referrer.value); fielda(t, -2, "Referrer");
		pushString(t, HttpHeader.RetryAfter.value); fielda(t, -2, "RetryAfter");
		pushString(t, HttpHeader.Server.value); fielda(t, -2, "Server");
		pushString(t, HttpHeader.ServletEngine.value); fielda(t, -2, "ServletEngine");
		pushString(t, HttpHeader.SetCookie.value); fielda(t, -2, "SetCookie");
		pushString(t, HttpHeader.SetCookie2.value); fielda(t, -2, "SetCookie2");
		pushString(t, HttpHeader.TE.value); fielda(t, -2, "TE");
		pushString(t, HttpHeader.Trailer.value); fielda(t, -2, "Trailer");
		pushString(t, HttpHeader.TransferEncoding.value); fielda(t, -2, "TransferEncoding");
		pushString(t, HttpHeader.Upgrade.value); fielda(t, -2, "Upgrade");
		pushString(t, HttpHeader.UserAgent.value); fielda(t, -2, "UserAgent");
		pushString(t, HttpHeader.Vary.value); fielda(t, -2, "Vary");
		pushString(t, HttpHeader.Warning.value); fielda(t, -2, "Warning");
		pushString(t, HttpHeader.WwwAuthenticate.value); fielda(t, -2, "WwwAuthenticate");
		
		newGlobal(t, "header");
	}
	
	void responseCode(CrocThread* t)
	{
		newNamespace(t, "responseCode");
		
		pushInt(t, HttpResponseCode.Continue); fielda(t, -2, "Continue");
		pushInt(t, HttpResponseCode.SwitchingProtocols); fielda(t, -2, "SwitchingProtocols");
		pushInt(t, HttpResponseCode.OK); fielda(t, -2, "OK");
		pushInt(t, HttpResponseCode.Created); fielda(t, -2, "Created");
		pushInt(t, HttpResponseCode.Accepted); fielda(t, -2, "Accepted");
		pushInt(t, HttpResponseCode.NonAuthoritativeInformation); fielda(t, -2, "NonAuthoritativeInformation");
		pushInt(t, HttpResponseCode.NoContent); fielda(t, -2, "NoContent");
		pushInt(t, HttpResponseCode.ResetContent); fielda(t, -2, "ResetContent");
		pushInt(t, HttpResponseCode.PartialContent); fielda(t, -2, "PartialContent");
		pushInt(t, HttpResponseCode.MultipleChoices); fielda(t, -2, "MultipleChoices");
		pushInt(t, HttpResponseCode.MovedPermanently); fielda(t, -2, "MovedPermanently");
		pushInt(t, HttpResponseCode.Found); fielda(t, -2, "Found");
		pushInt(t, HttpResponseCode.SeeOther); fielda(t, -2, "SeeOther");
		pushInt(t, HttpResponseCode.NotModified); fielda(t, -2, "NotModified");
		pushInt(t, HttpResponseCode.UseProxy); fielda(t, -2, "UseProxy");
		pushInt(t, HttpResponseCode.TemporaryRedirect); fielda(t, -2, "TemporaryRedirect");
		pushInt(t, HttpResponseCode.BadRequest); fielda(t, -2, "BadRequest");
		pushInt(t, HttpResponseCode.Unauthorized); fielda(t, -2, "Unauthorized");
		pushInt(t, HttpResponseCode.PaymentRequired); fielda(t, -2, "PaymentRequired");
		pushInt(t, HttpResponseCode.Forbidden); fielda(t, -2, "Forbidden");
		pushInt(t, HttpResponseCode.NotFound); fielda(t, -2, "NotFound");
		pushInt(t, HttpResponseCode.MethodNotAllowed); fielda(t, -2, "MethodNotAllowed");
		pushInt(t, HttpResponseCode.NotAcceptable); fielda(t, -2, "NotAcceptable");
		pushInt(t, HttpResponseCode.ProxyAuthenticationRequired); fielda(t, -2, "ProxyAuthenticationRequired");
		pushInt(t, HttpResponseCode.RequestTimeout); fielda(t, -2, "RequestTimeout");
		pushInt(t, HttpResponseCode.Conflict); fielda(t, -2, "Conflict");
		pushInt(t, HttpResponseCode.Gone); fielda(t, -2, "Gone");
		pushInt(t, HttpResponseCode.LengthRequired); fielda(t, -2, "LengthRequired");
		pushInt(t, HttpResponseCode.PreconditionFailed); fielda(t, -2, "PreconditionFailed");
		pushInt(t, HttpResponseCode.RequestEntityTooLarge); fielda(t, -2, "RequestEntityTooLarge");
		pushInt(t, HttpResponseCode.RequestURITooLarge); fielda(t, -2, "RequestURITooLarge");
		pushInt(t, HttpResponseCode.UnsupportedMediaType); fielda(t, -2, "UnsupportedMediaType");
		pushInt(t, HttpResponseCode.RequestedRangeNotSatisfiable); fielda(t, -2, "RequestedRangeNotSatisfiable");
		pushInt(t, HttpResponseCode.ExpectationFailed); fielda(t, -2, "ExpectationFailed");
		pushInt(t, HttpResponseCode.InternalServerError); fielda(t, -2, "InternalServerError");
		pushInt(t, HttpResponseCode.NotImplemented); fielda(t, -2, "NotImplemented");
		pushInt(t, HttpResponseCode.BadGateway); fielda(t, -2, "BadGateway");
		pushInt(t, HttpResponseCode.ServiceUnavailable); fielda(t, -2, "ServiceUnavailable");
		pushInt(t, HttpResponseCode.GatewayTimeout); fielda(t, -2, "GatewayTimeout");
		pushInt(t, HttpResponseCode.VersionNotSupported); fielda(t, -2, "VersionNotSupported");
		
		newGlobal(t, "responseCode");
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