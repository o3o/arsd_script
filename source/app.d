import std.stdio;

import arsd.script;
import tinyredis: Redis;
import tinyredis_util.util: get, set;
import vibe.data.json;

struct CopyData {
   /**
    * Elenco delle variabili da copiare
    *
    * Examples:
    * --------------------
    * "let": {
    *        "OVF": 999,
    *        "pi": 3.1415,
    *        "s": "`abc`",
    *        "x": "y"
    *        }
    * --------------------
    * copia in `OVF` l'intero 999, in `pi` il double 3.1415, in `s` la stringa abx  e in `x` il valore di y.
    */
   Json[string] let;
}

struct ScriptEngine {
   private var globals;
   private Redis redis;
   this(string scriptSource, Redis redis) {
      assert(redis !is null);
      this.redis = redis;
      globals = var.emptyObject;
      interpret(scriptSource, globals);
   }
   @disable this();


   //void opDispatch(string func, T...)(T t) {
   void call(T...)(T t) if(T.length != 0) {
   //void call(string func, T...)(T t) {
      import std.string: strip, startsWith, chompPrefix;
      import std.conv : to;
      string ret;
      var[] args;
      foreach(arg; t[1 .. $]) {
         if (arg.to!(string).startsWith("*int")) {
            redis.get!int(chompPrefix(arg.to!string, "*int").strip);
         } else if (arg.to!(string).startsWith("->")) {
            ret = chompPrefix(arg.to!string, "->").strip;
         } else {
            args ~= var(arg);
         }
      }
      string func = t[0].to!string;
      writeln(func);
      writeln(args);

      auto result = globals[func].apply(globals, args);
      if (ret.length) {
         redis.set(ret, result);
      }
   }

   void callA(string[] t) {
      import std.string: strip, startsWith, chompPrefix;
      import std.conv : to;
      string ret;
      var[] args;

      foreach(arg; t[1 .. $]) {
         writeln(arg);
         if (arg.to!(string).startsWith("*int")) {
            auto ai = redis.get!int(chompPrefix(arg.to!string, "*int").strip);
            args ~= var(ai);
         } else if (arg.to!(string).startsWith("->")) {
            ret = chompPrefix(arg.to!string, "->").strip;
         } else {
            args ~= var(arg);
         }
      }
      string func = t[0].to!string;
      writeln(args);
      auto result = globals[func].apply(globals, args);
      if (ret.length) {
         redis.set(ret, result);
      }
   }
}

struct NoMembers {
   private Redis redis;
   private var globals;
   this(string scriptSource, Redis redis) {
      assert(redis !is null);
      this.redis = redis;
      globals = var.emptyObject;
      interpret(scriptSource, globals);
   }

   void opDispatch(string func, T...)(T t) {
      import std.string: strip, startsWith, chompPrefix;
      import std.stdio : writeln;
      import std.conv : tp;
      writeln("Attempted to access member ", func);
      //if(func !in globals) {
         //throw new Exception("method \"" ~ func ~ "\" not found in script");
      //}
      string ret;
      var[] args;
      foreach(arg; t) {
         writeln(arg);
         /+
         if (startsWith(arg, "*int")) {
            //redis.get!int(chompPrefix(arg, "*int").strip);
         } else if (arg.startsWith("->")) {
            //ret = chompPrefix(arg, "->").strip;
         } else {
            //args ~= var(arg);
         }
         +/
      }
      /+
      auto result = globals[func].apply(globals, args);
      if (ret.length) {
         redis.set(ret, result);
      }
      +/
   }

/+
   void opDispatch(string func, T...)(T t) {
      foreach(arg; t) {
         writefln("\t%s", arg);
      }
   }
+/
}

void main() {
   import std.stdio;
   import std.file : readText;
   Redis redis = new Redis();

   Json json = parseJsonString(`{
         "let": {
            "OVF": ["sum", "a", "b"],
         }}`);

   /+
   foreach (string k, Json v; json["let"]) {
      writeln(k);
      writeln("----");

      foreach (e; v) {
         writeln(e);
      }

   context.call("sum", 5, 6, "->a");
   writefln("5 + 6 = %s", redis.get!int("a")); //11

   }
   +/

   string scriptSource = readText("s.js");

   ScriptEngine context = ScriptEngine(scriptSource, redis);


   //context.call!"sum"(5, 6, "->a");
   context.call("sum", 5, 6, "->a");
   writefln("5 + 6 = %s", redis.get!int("a")); //11
   redis.set!int("x", 42);
   redis.set!int("y", 2);
   string[] arr = ["sum", "*int x", "*int y", "->z"];
   context.callA(arr);
   writefln("x + y = %s", redis.get!int("z")); //24
}
