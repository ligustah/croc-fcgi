module lib.fcgi;

import lib.util;

import tango.io.device.Conduit;
import tango.io.device.Array;
import tango.io.device.File;
import tango.io.Stdout;
import tango.io.Console;
import tango.io.stream.Format;
import tango.io.stream.Buffered;

import tango.core.Exception;
import tango.core.Array;

import tango.sys.Environment;

import tango.stdc.stringz;
import stdio = tango.stdc.stdio;

import tango.net.http.HttpHeaders;
import tango.net.http.HttpCookies;
import tango.net.http.HttpConst;
import tango.net.http.HttpParams;

import tango.util.log.Log;

import Integer = tango.text.convert.Integer;
import Ascii = tango.text.Ascii;

private Logger log;

static this()
{
	log = Log.lookup("fcgi");
}

version(Windows)
{
	pragma(lib, "Ws2_32.lib");
}

extern(C)
{
	struct FCGX_Stream {
		ubyte* rdNext;
		ubyte* wrNext;
		ubyte* stop;
		ubyte* stopUnget;
		int isReader;
		int isClosed;
		int wasFCloseCalled;
		int FCGI_errno;
		void* function(FCGX_Stream* stream) fillBuffProc;
		void* function(FCGX_Stream* stream, int doClose) emptyBuffProc;
		void* data;
	}

	alias char** FCGX_ParamArray;

	int FCGX_Accept(FCGX_Stream** stdin, FCGX_Stream** stdout, FCGX_Stream** stderr, FCGX_ParamArray* envp);
	int FCGX_GetStr(char* str, int n, FCGX_Stream* stream);
	int FCGX_PutStr(char* str, int n, FCGX_Stream* stream);
	int FCGX_HasSeenEOF(FCGX_Stream* stream);
	int FCGX_FFlush(FCGX_Stream* stream);
	
	int FCGI_Accept();
}

class FCGI_InputStream : InputStream
{
	FCGX_Stream* _inStream;
	
	this(FCGX_Stream* inStream)
	{
		this._inStream = inStream;
	}
	
	size_t read(void[] dst)
	{
		if(FCGX_HasSeenEOF(_inStream) == stdio.EOF)
		{
			return IOStream.Eof;
		}
		auto len = FCGX_GetStr(cast(char*)dst.ptr, dst.length, _inStream);
		
		return len;
	}
	
	void[] load(size_t max = -1)
	{
		return Conduit.load(this, max);
	}
	
	InputStream input()
	{
		return this;
	}
	
	void close()
	{
		//ignored
	}
	
	long seek(long offset, Anchor anchor)
	{
		throw new IOException("operation not supported");
	}
	
	IConduit conduit()
	{
		return new FCGI_Conduit(_inStream, null);
	}
	
	typeof(this) flush()
	{
		return this;
	}
}

class FCGI_OutputStream : OutputStream
{
	FCGX_Stream* _outStream;
	void delegate(FCGI_OutputStream) _callback;
	
	this(FCGX_Stream* outStream, void delegate(FCGI_OutputStream) headerCallback = null)
	{
		this._outStream = outStream;
		this._callback = headerCallback;
	}
	
	size_t write(void[] src)
	{
		if(_callback)
		{
			auto cb = _callback;
			_callback = null;
			cb(this);
		}
		return FCGX_PutStr(cast(char*)src.ptr, src.length, _outStream);
	}
	
	OutputStream copy(InputStream src, size_t max = -1)
	{
		Conduit.transfer(src, this, max);
		return this;
	}
	
	void close()
	{
		//ignored
	}
	
	long seek(long offset, Anchor anchor)
	{
		throw new IOException("operation not supported");
	}
	
	IConduit conduit()
	{
		return new FCGI_Conduit(null, _outStream);
	}
	
	typeof(this) flush()
	{
		FCGX_FFlush(_outStream);
		return this;
	}
	
	typeof(this) output()
	{
		return this;
	}
}

class FCGI_Conduit : Conduit
{
	FCGX_Stream* _inStream, _outStream;

	this(FCGX_Stream* inStream, FCGX_Stream* outStream)
	{
		this._inStream = inStream;
		this._outStream = outStream;
	}
	
	size_t write(void[] src)
	{
		return FCGX_PutStr(cast(char*)src.ptr, src.length, _outStream);
	}
	
	size_t read(void[] dst)
	{
		return FCGX_GetStr(cast(char*)dst.ptr, dst.length, _inStream);
	}

	size_t bufferSize()
	{
		return 1024;
	}

	char[] toString()
	{
		return "FastCGIConduit";
	}

	void detach()
	{
		//do nothing here, stream is closed automatically
	}
}

class FCGI_Request
{
	private static HttpStatus[HttpResponseCode] _codeToStatus;
	
	static this()
	{
		_codeToStatus[HttpResponseCode.Continue] = HttpResponses.Continue;
		_codeToStatus[HttpResponseCode.SwitchingProtocols] = HttpResponses.SwitchingProtocols;
		_codeToStatus[HttpResponseCode.OK] = HttpResponses.OK;
		_codeToStatus[HttpResponseCode.Created] = HttpResponses.Created;
		_codeToStatus[HttpResponseCode.Accepted] = HttpResponses.Accepted;
		_codeToStatus[HttpResponseCode.NonAuthoritativeInformation] = HttpResponses.NonAuthoritativeInformation;
		_codeToStatus[HttpResponseCode.NoContent] = HttpResponses.NoContent;
		_codeToStatus[HttpResponseCode.ResetContent] = HttpResponses.ResetContent;
		_codeToStatus[HttpResponseCode.PartialContent] = HttpResponses.PartialContent;
		_codeToStatus[HttpResponseCode.MultipleChoices] = HttpResponses.MultipleChoices;
		_codeToStatus[HttpResponseCode.MovedPermanently] = HttpResponses.MovedPermanently;
		_codeToStatus[HttpResponseCode.Found] = HttpResponses.Found;
		_codeToStatus[HttpResponseCode.TemporaryRedirect] = HttpResponses.TemporaryRedirect;
		_codeToStatus[HttpResponseCode.SeeOther] = HttpResponses.SeeOther;
		_codeToStatus[HttpResponseCode.NotModified] = HttpResponses.NotModified;
		_codeToStatus[HttpResponseCode.UseProxy] = HttpResponses.UseProxy;
		_codeToStatus[HttpResponseCode.BadRequest] = HttpResponses.BadRequest;
		_codeToStatus[HttpResponseCode.Unauthorized] = HttpResponses.Unauthorized;
		_codeToStatus[HttpResponseCode.PaymentRequired] = HttpResponses.PaymentRequired;
		_codeToStatus[HttpResponseCode.Forbidden] = HttpResponses.Forbidden;
		_codeToStatus[HttpResponseCode.NotFound] = HttpResponses.NotFound;
		_codeToStatus[HttpResponseCode.MethodNotAllowed] = HttpResponses.MethodNotAllowed;
		_codeToStatus[HttpResponseCode.NotAcceptable] = HttpResponses.NotAcceptable;
		_codeToStatus[HttpResponseCode.ProxyAuthenticationRequired] = HttpResponses.ProxyAuthenticationRequired;
		_codeToStatus[HttpResponseCode.RequestTimeout] = HttpResponses.RequestTimeout;
		_codeToStatus[HttpResponseCode.Conflict] = HttpResponses.Conflict;
		_codeToStatus[HttpResponseCode.Gone] = HttpResponses.Gone;
		_codeToStatus[HttpResponseCode.LengthRequired] = HttpResponses.LengthRequired;
		_codeToStatus[HttpResponseCode.PreconditionFailed] = HttpResponses.PreconditionFailed;
		_codeToStatus[HttpResponseCode.RequestEntityTooLarge] = HttpResponses.RequestEntityTooLarge;
		_codeToStatus[HttpResponseCode.RequestURITooLarge] = HttpResponses.RequestURITooLarge;
		_codeToStatus[HttpResponseCode.UnsupportedMediaType] = HttpResponses.UnsupportedMediaType;
		_codeToStatus[HttpResponseCode.RequestedRangeNotSatisfiable] = HttpResponses.RequestedRangeNotSatisfiable;
		_codeToStatus[HttpResponseCode.ExpectationFailed] = HttpResponses.ExpectationFailed;
		_codeToStatus[HttpResponseCode.InternalServerError] = HttpResponses.InternalServerError;
		_codeToStatus[HttpResponseCode.NotImplemented] = HttpResponses.NotImplemented;
		_codeToStatus[HttpResponseCode.BadGateway] = HttpResponses.BadGateway;
		_codeToStatus[HttpResponseCode.ServiceUnavailable] = HttpResponses.ServiceUnavailable;
		_codeToStatus[HttpResponseCode.GatewayTimeout] = HttpResponses.GatewayTimeout;
		_codeToStatus[HttpResponseCode.VersionNotSupported] = HttpResponses.VersionNotSupported;
	}
	
	private FCGI_InputStream _in;
	private FCGI_OutputStream _out, _err;
	private char[][char[]] 	_env;
	private Cookie[char[]] _inCookies;
	private HttpParams _getParams;
	private HttpParams _postParams;
	private HttpHeaders _headers;
	private HttpCookies _cookies;
	private HttpStatus	_status;
	private bool _headersSent = false;

	this(FCGX_Stream* input, FCGX_Stream* output, FCGX_Stream* error, FCGX_ParamArray env)
	{
		this._in = new FCGI_InputStream(input);
		this._out = new FCGI_OutputStream(output, &flushHeaders);
		this._err = new FCGI_OutputStream(error);
		this._headers = new HttpHeaders();
		this._getParams = new HttpParams();
		this._postParams = new HttpParams();
		this._cookies = new HttpCookies(_headers);
		
		if(env != null)
		{
			for(; *env !is null; env++)
			{
				char[] p = fromStringz(*env);
				
				size_t pos = p.find('=');
				_env[p[0 .. pos]] = p[pos + 1 .. $];
			}
		}
		else
		{
			_env = Environment.get();
		}
		
		log.trace("got {} env params", _env.length);
	}
	
	public InputStream input()
	{
		return _in;
	}
	
	public OutputStream output()
	{
		return _out;
	}
	
	public OutputStream error()
	{
		return _err;
	}
	
	public char[][char[]] env()
	{
		return _env;
	}
	
	public Cookie[char[]] cookies()
	{
		return _inCookies;
	}
	
	public void setResponseCode(HttpResponseCode code)
	{
		_status = statusFromCode(code);
	}
	
	public HttpHeaders headers()
	{
		return _headers;
	}
	
	public HttpParams GETParams()
	{
    return _getParams;
	}
	
	public HttpParams POSTParams()
	{
		return _postParams;
	}
	
	public void addCookie(Cookie c)
	{
		return _cookies.add(c);
	}
	
	/**
		output all headers before any content is sent
	*/
	private void flushHeaders(FCGI_OutputStream outs)
	{
		if(_headersSent)
			return;
		_headersSent = true;
		if(_status != HttpStatus.init)
		{
			_headers.add(HttpHeaderName("Status:"), Integer.toString(_status.code) ~ " " ~ _status.name);
		}	//else: let fcgi host decide about that
		if(!_headers.get(HttpHeader.ContentType))
		{
			//default to text/html
			_headers.add(HttpHeader.ContentType, "text/html");
		}
		_headers.produce(&outs.write, "\r\n");
		outs.write("\r\n");
	}
	
	package void parse()
	{
		if("HTTP_COOKIE" in _env)
		{
			auto stack = new CookieStack(10);
			auto parser = new CookieParser(stack);
			parser.parse(_env["HTTP_COOKIE"]);
			
			foreach(cookie; stack)
			{
				_inCookies[cookie.name] = cookie;
			}
			
			log.trace("parsed {} cookies", _inCookies.length);
		}
		
		if("QUERY_STRING" in _env)
		{
			_getParams.parse(new Array(_env["QUERY_STRING"]));
			log.trace("parsed {} GET params", _getParams.size);
		}

		//TODO: check for content type here and do not load multi parts into memory
		if("REQUEST_METHOD" in _env && _env["REQUEST_METHOD"] == "POST")
		{
			int len = Integer.parse(_env["CONTENT_LENGTH"]);
			char[] type = _env["CONTENT_TYPE"];
			Ascii.toLower(type);
			log.trace("CONTENT_LENGTH: {}", len);
			log.trace("CONTENT_TYPE: {}", type);
			
			switch(type)
			{
				case "application/x-www-form-urlencoded":
					_postParams.parse(cast(char[])_in.load(len));
					break;
				default:
					log.warn("unknown form data encoding: {}, dumping data", type);
					scope f = new File(getExeDir().append("form_data.txt").toString, File.ReadWriteCreate);
					f.copy(_in, len);
					break;
			}
			 
			 log.trace("parsed {} POST params", _postParams.size);
		}
	}
	
	/**
		ensures that all headers are sent in case no content was sent (i.e. on HTTP 3xx)
	*/
	public void finish()
	{
		if(!_headersSent)
			flushHeaders(_out);
	}
	
	private HttpStatus statusFromCode(HttpResponseCode code)
	{
		return _codeToStatus[code];
	}
}

struct FCGX
{
	/**
		Accept a connection and return all the relevant streams.
		
		mapStreams = 	if true, this will replace Stdout/Stderr to output
						to the FCGI streams
	*/
	public static int accept(out FCGI_Request req, bool mapStreams = false)
	{
		FCGX_Stream* _in, _out, _err;
		FCGX_ParamArray _env;
		
		int code = accept(&_in, &_out, &_err, &_env);
		req = new FCGI_Request(_in, _out, _err, _env);
		
		if(mapStreams)
		{
			auto layout = Stdout.layout;
			
			Stdout = new FormatOutput!(char)(layout, req.output);
			Stderr = new FormatOutput!(char)(layout, req.error);
		}
		
		req.parse();
		
		return code;
	}
	
	/**
		Wrapper for FCGX_Accept.
	*/	
	public static int accept(
		FCGX_Stream** stdin,
		FCGX_Stream** stdout,
		FCGX_Stream** stderr,
		FCGX_ParamArray* envp
	)
	{
		return FCGX_Accept(stdin, stdout, stderr, envp);
	}
}