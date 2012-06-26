module session;

import lib.fcgi;
import lib.util;

import tango.io.device.File;

import tango.util.digest.Sha1;

import TimeStamp = tango.text.convert.TimeStamp;
import tango.time.Time;
import tango.time.Clock;

import tango.net.http.HttpCookies;

import croc.api;
import croc.api_debug;
import croc.serialization;

import tango.util.log.Log;

private Logger log;

static this()
{
	log = Log.lookup("mod_session");
}

version(Windows)
{
	import tango.sys.win32.UserGdi;
}
else version(linux)
{
	import tango.sys.linux.linux;
}

void session_init(CrocThread* t)
{
	makeModule(t, "session", &SessionModule.init);
}

struct SessionModule
{
static:
	private Session getCurrent(CrocThread* t)
	{
		try
		{
			return getRegistryObject!(Session)(t, registryName);
		}
		catch(CrocException e)
		{
			catchException(t);
			pop(t);
			
			throwStdException(t, "ApiError", "No currently open session found");
		}
	}
	
	/**
		Returns the currently active session
	*/
	uword get(CrocThread* t)
	{
		getCurrent(t).pushSession(t);		
		return 1;
	}
	
	uword open(CrocThread* t)
	{
		if(hasRegistryVar(t, registryName))
		{
			//should this be a nop instead?
			throwStdException(t, "ApiError", "Cannot open session, already opened");
		}
		
		pushRegistryObject(t, registryName, new Session(t));
		
		return 0;
	}
	
	
	/**
		Save the currently opened session to disk and release its lock.
	*/
	uword close(CrocThread* t)
	{		
		if(hasRegistryVar(t, registryName))
		{
			getCurrent(t).close(t);
		
			getRegistry(t);
			pushString(t, registryName);
			removeKey(t, -2);
			pop(t);
		}
		return 0;
	}
	
	uword id(CrocThread* t)
	{
		pushString(t, getCurrent(t).id);
		return 1;
	}

	uword init(CrocThread* t)
	{
		newFunction(t, &close, "close", 0);		newGlobal(t, "close");
		newFunction(t, &open, "open", 0);		newGlobal(t, "open");
		newFunction(t, &get, "get", 0);			newGlobal(t, "get");
		newFunction(t, &id, "id", 0);			newGlobal(t, "id");
		
		open(t);
		return 0;
	}
		
	public const char[] registryName = "session.current";
	public const char[] cookieName = "crocsession";
}

/**
	This class is used to internally store all information
	connected to one session.
*/
class Session
{
	private ulong 			_sessionRef;
	private LockedFile		_sessionFile;
	private Cookie			_sessionCookie;
	private char[] 			_id;
	private CrocThread*		_t;
	
	this(CrocThread* t)
	{
		_t = t;
		
		stackCheck(t,
		{
			//grab the session cookie
			Cookie* cptr = SessionModule.cookieName in getRequest(t).cookies;
			if(cptr)
			{
				_id = (*cptr).value;
				_sessionCookie = *cptr;
			}
			
			if(!validID(_id))	//either invalid or empty
			{
				_id = createID(getRequest(t));
				
				_sessionCookie = new Cookie(SessionModule.cookieName, id);
				
				//add our session cookie
				getRequest(t).addCookie(_sessionCookie);
			}
			
			_sessionFile = new LockedFile(getExeDir().append("session_" ~ _id).toString);
			_sessionFile.lock();
			
			if(_sessionFile.length)
			{
				//load the stored session
				auto trans = newTable(t);
				deserializeGraph(t, trans, _sessionFile);
				
				//bring trans table on top
				swap(t);
				//and pop it
				pop(t);
			}
			else
			{
				//start a new session
				newTable(t);
			}
			
			//session table on top
			_sessionRef = createRef(t, -1);
			pop(t);
		});
	}
	
	~this()
	{
		_sessionFile.close();
	}
	
	public Cookie getCookie()
	{
		return _sessionCookie;
	}
	
	public void pushSession(CrocThread* t)
	{
		pushRef(t, _sessionRef);
	}
	
	public void close(CrocThread* t)
	{
		_sessionFile.seek(0);
		auto slot = pushRef(t, _sessionRef);
		serializeGraph(t, slot, newTable(t), _sessionFile);
		pop(t, 2);
		
		_sessionFile.truncate();
		_sessionFile.close();
	}
	
	public char[] id()
	{
		return _id;
	}
	
	private static char[] createID(FCGI_Request r)
	{
		auto sha = new Sha1();
		auto p = r.env;
		sha.update(p["REMOTE_ADDR"]);
		sha.update(TimeStamp.toString(Clock.now));
		
		return sha.hexDigest();
	}
	
		
	/**
		returns true if the id passed is valid
	*/
	private static bool validID(char[] id)
	{
		//will add more checks later on
		return id.length > 0;
	}
}

class LockedFile : File
{
	private bool _locked = false;
	
	this(char[] path)
	{
		super(path, Style(Access.ReadWrite, Open.Sedate, /*we take care of locking ourselves*/Share.ReadWrite));
	}
	
	~this()
	{
		close();
	}
	
	public override void close()
	{
		if(_locked)
		{
			//explicitly unlock file on close
			release();
			super.close();
		}
	}
	
	public void release()
	{
		if(!_locked)
			return;
		_release();
		_locked = false;
	}
	
	public bool lock(bool blocking = true)
	{
		bool l = _lock(blocking);
		_locked = true;
		return l;
	}
	
	public bool isLocked()
	{
		return _locked;
	}

	version(Windows)
	{	
		private void _release()
		{
			HANDLE handle = cast(HANDLE) super.fileHandle;
			DWORD low = 1, high = 0;
			OVERLAPPED offset = {0, 0, 0, 0, NULL};
			
			UnlockFileEx(handle, 0, low, high, &offset);
		}
		
		private bool _lock(bool blocking = true)
		{
			HANDLE handle = cast(HANDLE) super.fileHandle;
			DWORD low = 1, high = 0;
			OVERLAPPED offset = {0, 0, 0, 0, NULL};
			
			DWORD flags = LOCKFILE_EXCLUSIVE_LOCK;
			if(!blocking)
				flags |= LOCKFILE_FAIL_IMMEDIATELY;

			return cast(bool)LockFileEx(handle, flags, 0, low, high, &offset);
		}
	}
	else version(linux)
	{
		private void _release()
		{
			flock(super.fileHandle, LOCK_UN);
		}
		
		private bool _lock(bool blocking = true)
		{
			int op = LOCK_EX;
			if(!blocking)
				op |= LOCK_NB;
				
			int ret = flock(super.fileHandle, op);
			return ret == 0;
		}
	}
	else
	{
		static assert(0, "session module won't compile on your system");
	}
}