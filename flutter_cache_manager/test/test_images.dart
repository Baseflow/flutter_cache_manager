/// Images used by the tests, embedded as base64 so they can be decoded
/// without a file system.
///
/// `flutter test --platform chrome` cannot read files: `dart:io` is not
/// available there. Keeping the bytes in the test bundle lets the same tests
/// run on the VM and in the browser, so the resize behaviour on web (where
/// `ImageDescriptor.width` and `height` are not supported) is covered too.
///
/// All of them are 120x120, the minimal size the resize tests need, and are
/// kept as small as possible to stay readable. They were made with Pillow:
///
/// ```python
/// img = Image.new('RGB', (120, 120), (32, 96, 192))
/// img.quantize(colors=8).save('image-120.png', optimize=True)
/// ```
library;

/// Static 120x120 png.
const imagePng120 =
    'iVBORw0KGgoAAAANSUhEUgAAAHgAAAB4AgMAAABECt5BAAAACVBMVEXwyB4gYMDIKCiUsMyeAA'
    'ABLElEQVR42u2WMY6DMBBFvwlIKV1kqbfMMXwEit2jpcwNUnAEH4UDpKAHydtkE+aPjWIJ7VKY'
    'Ann8mD/jGRswkNeHE2aF1avgggsueH+41lNNh3BLejcdYL5S2HSvewQ//BoXxc3v4AQAOBC+Po'
    'O0g/ZemDYifqYwJH5ZjNuBvYVllfiZF3FIagPtIL0pT0szR9WunH5/UncotQv5tkO1tnNsTuyj'
    '3mlVOjPAoP5efF7XxZ2i7v3UjKZ2szMWOU/1ZuJWU/NXLw9XXpp7w/4fY4+ahs3EZ03nzcSDpm'
    'OGuC66z/BWZQsCq4XPOR1TKxulN6fuJR45s6zdMnPiEgfOjMQ9WxLfl8ak+h14HRWS6l7ju9Rm'
    'HKhGXJb++aCP4UmGUUV9/GtNPo5D/7oDP+j1N9kWT81DAAAAAElFTkSuQmCC';

/// Static 120x120 webp.
const imageWebp120 =
    'UklGRkwCAABXRUJQVlA4IEACAACQEQCdASp4AHgAPrVUpk0nJKOiJhqqAOAWiU3cLiYSKsP51q'
    '/3K/yI5wvQJc751vEv+O+6D3Af1X2AeJL/ouoB5hv2f/Yz3gPRf6AH9V/wHWM+hf5ZPsc/tv6U'
    'GaAALATZ5zdWBUWGhxz4FTEPHNR0FuBf+9ssCqNsqCPqki1UQ64OdJja38kSq5/xgZ5tuoLo8J'
    'yBwAD+/J6P50uqCJS7mhfSQwrrk/5whJQucgetgOr9CbPgqPoP5Mtthf7Zsg3LCZJJVeRgMYar'
    'xMaOl6ibLZ13kJWCCHd0SFjAZOv6vcMEAlCrdGnpiGMKMuc6xpxp5y0JeDddJwx8v4hbFiSiHa'
    'O+g5jKsu3/Uza13TTikWaTPxxHXB9GzQogAx0VyHkTTSH6SHz5Q9U8n3b9ceAvd2MqPOWASocs'
    'AcPJXUH0L37dNrBrpXkHelAHkNtrhp6odEkbgDO5ygFKJ7hLEITJ+f5khCBWLCLE0VM9yhb/sC'
    'p/po7UFmju89OX0T2nymo6io3i+K0FXloS8G2ALP8EpHOHpVZ/+fg7ZuNW/+DjDOVAdBJ8SncC'
    'ShE+X3ZjAhAj2toEDwxfRmCvqeAYyHvqf3TNWXrIqbTgyobZLU4zhFs6DCxRH1L8zKcev/ducr'
    'ijGfLQPbmd0myX/QL0s2bQrlv/iKwtbK6CZ2zLzovSHJFy83eD4mb+gBHGhWs4kKnxit4YGnaR'
    'VTcx/fGt4PFTsKybpx+1iJjLZ8qEfDV8LwiWchM9zC8nok5K60dkoAA=';

/// Static 120x120 bmp.
const imageBmp120 =
    'Qk2+BwAAAAAAAD4AAAAoAAAAeAAAAHgAAAABAAEAAAAAAIAHAADEDgAAxA4AAAIAAAACAAAAAA'
    'AAAP///wCSSSSUklJJSSySkkkkooQAJJJJISSEkpKBJSSSSRQpAEkkkkpJKSUkqkhKVJSlUgCS'
    'SSSUklJQSSSSkoEikIQAJJZJISSEipJJJSSqVCUpAElAkkpJKSkkkkhJJIVIkgCSVSSUkpKSSS'
    'SSkkkolSQAJJJJISREpJJJKSSSRSJJAEkkkkpJqQkkkkRJJVCUkgCSSSSklBJSSSSqkkgtSSQA'
    'JJJJESKkpJJJCSSVQJJJAEkkkmpUSQkkklJJJJUkkgCSSSUEgpJSySykkkkqSSQAJJJIqVUkiB'
    'KBCSSSQJVJAEkqlRJISVKkqlJJJJUgkgCSQSSkkpIkSSSkqkkiVSQAJKpJKSUlSpJJCQSSVJJZ'
    'AEkkkkJISSkkklKpJIkkggCSSSSUkpJCSSUkkklSSSoAJJJJKSkklJJIiSSSJJJUAEkkkkJESS'
    'kklVJJKUkkgQCSSSSUqpJSSSEkkkpSSSoAJJJJKQkkhJJKSSSQhJJUAEkkklJSSSkklJJJJSkk'
    'gQCSSSUEpJJSSSEkkkpSSSoAJJJIqQkkhKJKSSSQhJJEAEkqkpJSSSlUlJJJJSkkqQCSQSUkpJ'
    'JECSEkkkpEkpIAJKpISQkkqVJKSSSQqSQkAEkkkpJSyRIklJLJJRKpSQCSSSUkiBKlSSEkEkik'
    'EpIAJJJISVKklJKWSqSVSqQkAEkkkpIkSSEkQJCSUhJJSQCSSSUpSpJKSrUlJISklJIAJJSQpS'
    'kklJECSlKpSSIkAEklVQhCSSEqVJCUEhJVSQCSSEJSlJJKQUlFIqSkhJIAJJKUpEkkpKoSKkpJ'
    'SSkkAEklKQqSSSkkpVCUkhJSSgCSSEJRJJJKSRCFISqkhJEAJJKUikkkkJKlKkpISSkqAEkkUl'
    'SSSSUkSJCUkpJSQQCSioUhJJJKSpUlISUlBKoAJFEpSkkkkJJSSkpISKkkAElKRCqVSSUkhJCk'
    'kpUSSQCSkqlAoJJSSSklESUkpJIAJCQlVRUkiJJEkqpKSUkkAElJSBJSSVUkqUgkkJKSSQCSkp'
    'akpJISSRIlSSUkJJIAJCQgSQkkpJKlVJJKSUkkAElJSpJSSUkklCEkkJKSSQCSkpEkpJISSSFK'
    'SSUkJJIAJCQqSQkkpJJKlJJKSUkkAElJRJJSUUkklCEokJSSSQCSJSkkiUoSSSFKRSUiJVIAJU'
    'hSSVIUqSJalJSSVUgkAEiShJIkoUSUgSEpSoSVSQBVKSlVSkoVSSpKQlApJJIAAEREABEUqFJU'
    'lJSVUkkkAP+7uv/u6UKEgSkpJISSSQCq7u+qu7oVKSpCQkkpJJIA/7u9f+7uqFJElJSSUkkkAK'
    'ru1+q7ukKEqSlJJISSSQD/u/6/7u6VKRJCIkkpJJIAqu6r6ru7KESklVSSSklJAP+7/r/u78Wp'
    'SShJJKESJACq7qvqu7rIEhJCkkkWpUkA/7v+3+7vsqSklSSUoEkqAKruq7q7uuRJEkhJIkqSQQ'
    'D/u/737u+6lKSSklURJKoAqu7V3Vu26kJKSSSEqkkkAP+7f7f++76UkSRJKSSSSQCq77b+q67r'
    'qyqSklJJJJIA/7r7q/77fqBCSSSEkkkkAKrvrv6rr6vqlKRJKSSSSQD/uvur/vr+uSkqklJJJJ'
    'IAqu+u/quvq+pCQkkEkkkkAP+2+6v++v65FJSkqSSSSQCq+69+q6+r6qkpKVJJJJIA/6766/76'
    '/rhCQkoEkkkkAKr7b96rr6vqlJSSqSWSSQD/r7t1/vr+uSkpJJJIJJIAqvrt36uvq+pCQkkkpU'
    'kkAP+vvvr++365FJSSSRCSSQCq+uuvq63r6mlJJJJVJJIA/6+++37/vtkCIkkpQlUkAKr6663r'
    'qut6VVSSShSCVQD/r77/vv+/6ohJJJKpVIIAqvrrquuq6rhSkkkkkklUAP+vvv++/7/qpSSSSS'
    'SSSQCq+uuq66rquQhJSJJJJJIA/6++/77/v+pSkiUkkkkkAKr666rrquq5JSVSSSSSSQD/t79/'
    'v3+/6khIJJJJJJIAqt7q6urq6rkqlUkkkkkkAP/7v9+/37/qQSSSSSSSSQCqru167XrtWSpJJJ'
    'JJJJIA//u717vXu/pEkkkkkkkkAKqu737vfu9pKSSSSSSSSQD/+73bvdu92pJJJJJJJJIAqq7X'
    'btdu13hUkkkkkkkkAP/7/fv9+/3qgSVSqVSqSQCqrVatVq1WuSpIJBIJBJYA/////////+pElU'
    'qlUqlAAKqqqqqqqqq0qSSSSSSSVQD/////////+RJJJJJJJJIAqqqqqqqqqqqkkkkkkkkkAP//'
    '///////4SSSSSSSSSQCqqqqqqqqqqpJJJJJJJJIA//////////kkkkkkkkkkAKqqqqqqqqqqUS'
    'SSSSSSSQD/////////+QpJJJJJJJIAqqqqqqqqqqpUkkkkkkkkAP/////////5ISSSSSSSSQCq'
    'qqqqqqqqqkpJJJJJJJIA//////////kkkkkkkkkkAKqqqqqqqqqqSSSSSSSSSQD/////////+S'
    'SSSSSSSSQAqqqqqqqqqqpJJJJJJJJJAP/////////5JJJJJJJJJAA=';

/// Animated (3 frames) 120x120 gif.
const animatedGif120 =
    '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';

/// Animated (3 frames) 120x120 webp.
const animatedWebp120 =
    'UklGRsACAABXRUJQVlA4WAoAAAASAAAAdwAAdwAAQU5JTQYAAAAAAAAAAABBTk1GngAAAAAAAA'
    'AAAHcAAHcAAGQAAAJWUDgghgAAADAIAJ0BKngAeAA+0WStUaglJCKknjgBABoJZ27dX3DAABu+'
    'iAfwGtaZ9ow/6ZF5Iumvx5lQGRlGupsIxacZ2/KzBCi0yBCl3ZgAAP7zB/EqJeD9BD//N5uQfy'
    'UzKbkH27f+vb+By5BynUViE1OcSDwTUi2oi3VHfCEwysjzhCYZWR5whAAAQU5NRuoAAAAAAAAA'
    'AAB3AAB3AABkAAAAQUxQSBYAAAABDzD/ERFCTEPoX1oCpy2i/xNgOpwIVlA4ILQAAAC0CQCdAS'
    'p4AHgAPtFiqk8CiIAAAaCWVu3V9bJn+IGz4cz/CBLAADnRE39Ug42uYKZLMS8Ri+tzVIopfv5l'
    '/v2p1JynJZM+zaHpTzvmX+/bGm0Zll2MAAD+3hozTB+Z4Lt/gXHce/tFTcvMFZfsxNPrQESvY+'
    'aw+mSv+2OB6uNl/a0ZtOJY+besf+WgR/l67hT9e3ns2d6U4dM1JoigbeEVEjMCCfF56uEOzIAI'
    'wcgAjhyAAABBTk1G/AAAAAAAAAAAAHcAAHcAAGQAAABBTFBIFgAAAAEPMP8REUJMQ+hfWgKnLa'
    'L/E2A+XAhWUDggxgAAAPQIAJ0BKngAeAA+0WKmTwKIlYABoJY27dXpzawCJqvkzIfQGNaRvTBb'
    'SX3uFhmq+sJIY+oFjax57YzSxIwT2xmhOT2kLnIVkYJ7YzSxIwHAAP7tCH//zNH75PsN5Af+J/'
    'D4djBSt/0IMH/t/qif6mdXfa0f1M74VG3IL/NWrelE4S4m+dTGVYWq+dUrY9Mh5VyiMuw3TD4g'
    'rStK/suynznFY9+IIR1h27tiyviT1KWzOMs0khTL+rzSBUKzAgTvyksmlCQAAA==';

/// Animated (3 frames) 120x120 png.
const animatedApng120 =
    'iVBORw0KGgoAAAANSUhEUgAAAHgAAAB4AQMAAAADqqSRAAAABlBMVEUAgP8KCgrdKYvuAAAACG'
    'FjVEwAAAADAAAAAM7tusAAAAAaZmNUTAAAAAAAAAB4AAAAeAAAAAAAAAAAAAEACgAAjNzB+AAA'
    'ACVJREFUeNpjYGBgYGBgkP8PBUwMqGCUP8of5Y/yR/mj/FE+9fkA17QJBpLlpncAAAAaZmNUTA'
    'AAAAEAAAB4AAAAeAAAAAAAAAAAAAEACgAAF68rLAAAAClmZEFUAAAAAnja7cchEgAgDMCwHnyc'
    'n3caP9m4AFxVfQCHX++99973P/4eB2zCVlVhAAAAGmZjVEwAAAADAAAAeAAAAHgAAAAAAAAAAA'
    'ABAAoAAPo5+MUAAAArZmRBVAAAAAR42mNggAD+////////j4GJARWM8kf5o/xR/ih/lD/Kpz4f'
    'AH2rBvcc4MJOAAAAAElFTkSuQmCC';
