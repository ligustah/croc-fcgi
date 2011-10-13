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
	/**
		Returns the currently active session or creates a new session
	*/
	uword get(CrocThread* t)
	{
		char[] id;
		LockedFile file;
	
		getRegistry(t);
		pushString(t, registryName);
		if(!opin(t, -1, -2))
		{
			//we don't have the session object cached
			//check for session cookie
			Cookie* cptr = cookieName in getRequest(t).cookies;
			if(cptr)
			{
				id = (*cptr).value;
			}
			
			if(!validID(id))	//either invalid or empty
			{
				id = createID(getRequest(t));
				
				//add our session cookie
				getRequest(t).addCookie(new Cookie(cookieName, id));
			}
			
			pushString(t, id);
			setRegistryVar(t, "session.id");
			
			file = new LockedFile(sessionPath ~ "session_" ~ id);
			file.lock();
			
			pushRegistryObject(t, "session.lockFile", file);
			
			log.trace("session file length: {}", file.length);
			
			if(file.length)
			{
				//load the stored session
				auto trans = newTable(t);
				deserializeGraph(t, trans, file);
				
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
			setRegistryVar(t, registryName);
		}
		
		// registryName is still on the stack
		field(t, -2);
		
		return 1;
	}
	
	uword close(CrocThread* t)
	{
		LockedFile f = getRegistryObject!(LockedFile)(t, "session.lockFile");
		f.seek(0);
		auto slot = getRegistryVar(t, registryName);
		serializeGraph(t, slot, newTable(t), f);
		f.truncate();
		
		f.close();
		return 0;
	}
	
	uword id(CrocThread* t)
	{
		getRegistryVar(t, "session.id");
		
		return 1;
	}

	uword init(CrocThread* t)
	{
		newFunction(t, &close, "close", 0);		newGlobal(t, "close");
		newFunction(t, &get, "get", 0);			newGlobal(t, "get");
		newFunction(t, &id, "id", 0);			newGlobal(t, "id");
		return 0;
	}
	
	/**
		returns true if the id passed is valid
	*/
	bool validID(char[] id)
	{
		//will add more checks later on
		return id.length > 0;
	}
	
	char[] createID(FCGI_Request r)
	{
		auto sha = new Sha1();
		auto p = r.env;
		sha.update(p["REMOTE_ADDR"]);
		sha.update(TimeStamp.toString(Clock.now));
		
		return sha.hexDigest();
	}
	
	private const char[] registryName = "session.current";
	private const char[] cookieName = "crocsession";
	private const char[] sessionPath = "C:\\Users\\Andre\\Documents\\croc-fcgi\\";
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
		//explicitly unlock file on close
		release();
		super.close();
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