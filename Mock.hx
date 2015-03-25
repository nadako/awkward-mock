import haxe.Constraints.Function;

#if macro
import haxe.macro.Compiler;
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.MacroStringTools;
import haxe.macro.Type;
using haxe.macro.Tools;
#end

@:dce
class Mock {
    public static macro function mockMethod(method, ?returnValue) {
        var tExpr = Context.typeExpr(method);
        switch [tExpr.expr, tExpr.t] {
            case [TField(eobj, FInstance(c, cf) | FStatic(c, cf)), TFun(args, ret)]:
                var eobj = Context.storeTypedExpr(eobj);

                var hasReturnValue = switch (returnValue) {
                    case macro null: false;
                    default: true;
                }

                switch (ret) {
                    case TAbstract(_.get() => ab, _):
                        if (hasReturnValue) {
                            if (ab.pack.length == 0 && ab.name == "Void")
                                throw new Error("Mocked method doesn't return a value", returnValue.pos);
                        } else if (ab.meta.has(":notNull")) {
                            throw new Error("Return value required", returnValue.pos);
                        }
                    default:
                }

                var methodName = cf.get().name;

                if (Context.defined("cs")) {
                    var c = c.get();
                    registerMock(c.pack.concat([c.name, methodName]));
                }

                var retCT = ret.toComplexType();
                return macro @:pos(Context.currentPos()) new Mock.MethodMock($eobj, $v{methodName}, $v{args.length}, @:pos(returnValue.pos) ($returnValue : $retCT));
            default:
                throw new Error('${tExpr.t.toString()} should be a method', method.pos);
        }
    }

    #if macro
    static var mocks = new Map<String,Bool>();
    static var onGenerateAdded = false;

    static function registerMock(path:Array<String>) {
        if (Context.defined("applying_mocks")) {
            trace("not registering mock for " + path + " (applying phase)");
            return;
        }
        trace("registering mock for " + path);
        mocks[path.join(".")] = true;
        if (!onGenerateAdded)
            Context.onGenerate(function(_) {
                trace("saving mocks");
                var paths = [for (k in mocks.keys()) k.split(".")];
                sys.io.File.saveContent(".mocks.tmp", haxe.Json.stringify(paths));
            });
    }
    #end
}

@:nativeGen
class MethodMock {
    public var calls(default,null):Array<Array<Dynamic>>;

    var object:Dynamic;
    var methodName:Dynamic;
    var original:Function;

    public function new(object:Dynamic, methodName:String, numArgs:Int, returnValue:Dynamic) {
        this.calls = [];
        this.object = object;
        this.methodName = methodName;
        this.original = Reflect.field(object, methodName);
        Reflect.setField(object, methodName, Reflect.makeVarArgs(function(args) {
            // pad with nulls so the result is same on C# and JS
            for (i in 0...numArgs - args.length)
                args.push(null);
            calls.push(args);
            return returnValue;
        }));
    }

    public function dispose():Void {
        Reflect.setField(object, methodName, original);
        object = null;
        methodName = null;
        original = null;
    }
}

#if macro
class MockBuild {
    static function build(data:String):Array<Field> {
        var methodNames = data.split(",");
        var fields = Context.getBuildFields();
        trace("adding mocks for " + Context.getLocalType().toString() + ": " + methodNames);
        for (field in fields) {
            if (methodNames.indexOf(field.name) != -1 && field.access.indexOf(ADynamic) == -1) {
                trace("-> making " + field.name + " dynamic");
                field.access.push(ADynamic);
            }
        }
        return fields;
    }

    static function apply() {
        trace("applying mocks");
        Compiler.define("applying_mocks");

        if (!sys.FileSystem.exists(".mocks.tmp")) {
            trace("no mocks file found!");
            return;
        }

        var paths:Array<Array<String>> = haxe.Json.parse(sys.io.File.getContent(".mocks.tmp"));
        sys.FileSystem.deleteFile(".mocks.tmp");

        var classes = new Map<String,Array<String>>();
        for (path in paths) {
            var methodName = path.pop();
            var key = path.join(".");
            if (!classes.exists(key)) classes[key] = [];
            trace("found mock in " + key + ": " + methodName);
            classes[key].push(methodName);
        }

        for (cls in classes.keys()) {
            var methodNames = classes[cls];
            Compiler.addMetadata("@:build(Mock.MockBuild.build('" + methodNames.join(",") + "'))", cls);
        }
    }
}
#end
