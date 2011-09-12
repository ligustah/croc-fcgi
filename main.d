module main;

import lib.fcgi;

import tango.io.Stdout;

void main()
{
	FCGI_Request r;
	
	while(FCGX.accept(r, true) >= 0)
	{
		Stdout("Content-Type: text/plain").newline.newline;
		
		foreach(k,v; r.params())
		{
			Stdout.formatln("{} => {}", k, v);
		}
	}
}