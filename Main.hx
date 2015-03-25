class Main {
    static function main() {
        Main.doStuff("world");
        var mocked = Mock.mockMethod(doStuff, 666);
        Main.doStuff("a");
        trace(Main.doStuff());
        trace(mocked.calls);
        mocked.dispose();
        Main.doStuff("hey");

        cs.system.Console.ReadKey();
    }

    static function doStuff(?who:String) {
        trace("orig " + who);
        return 123;
    }
}
