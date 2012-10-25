module templates;
import croc.api;
import croc.api_debug;
import croc.serialization;
import tango.io.device.Array;
import tango.io.Stdout;

void templates_init(CrocThread* t)
{
	auto table = getRegistryVar(t, "fcgi.scriptModules");
	pushString(t, "templates");
	pushString(t, module_data);
	fielda(t, table);
	pop(t);

}

private const char[] module_data =
`module templates

global function test()
{
	writeln $ "blubb"
}

global t = "lala"

function main()
{
	writeln $ "main"
}`;