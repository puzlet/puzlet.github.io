// Generated by CoffeeScript 1.3.3
(function() {
  var ArrayMath, AxesLabels, BlabCoffee, BlabPlotter, BlabPrinter, CoffeeEvaluator, ComplexMath, EvalBoxPlotter, Figure, MathJaxProcessor, NumericFunctions, OLDloadJS, Resources, ScalarMath, TypeMath, getBlab, getBlabId, getFileDivs, githubForkRibbon, htmlNode, init, init0, init1, initNew, loadExtrasJs, loadJQuery, loadJS, loadMainCss, loadMainHtml, loadMainJs,
    __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

  BlabCoffee = (function() {

    BlabCoffee.prototype.predefinedCoffee = "nm = numeric\nsize = nm.size\nmax = nm.max\nabs = nm.abs\npow = nm.pow\nsqrt = nm.sqrt\nexp = nm.exp\nlog = nm.log\nsin = nm.sin\ncos = nm.cos\ntan = nm.tan\nasin = nm.asin\nacos = nm.acos\natan = nm.atan\natan2 = nm.atan2\nceil = nm.ceil\nfloor = nm.floor\nround = nm.round\nrand = nm.rand\ncomplex = nm.complex\nconj = nm.conj\nlinspace = nm.linspace\nprint = nm.print\nplot = nm.plot\nplotSeries = nm.plotSeries\neplot = nm.plot\nfigure = nm.figure\npi = Math.PI\nj = complex 0, 1\nprint.clear()\neplot.clear()";

    BlabCoffee.prototype.basicOps = [["add", "add"], ["sub", "subtract"], ["mul", "multiply"], ["div", "divide"]];

    BlabCoffee.prototype.modOp = ["mod", "modulo"];

    BlabCoffee.prototype.eqOps = [["mod", "modulo"], ["eq", "equals"], ["lt", "lt"], ["gt", "gt"], ["leq", "leq"], ["geq", "geq"]];

    BlabCoffee.prototype.assignOps = ["addeq", "subeq", "muleq", "diveq", "modeq"];

    function BlabCoffee() {
      this.ops = this.basicOps.concat([this.modOp]).concat(this.eqOps);
      this.predefinedCoffeeLines = this.predefinedCoffee.split("\n");
    }

    BlabCoffee.prototype.initializeMath = function() {
      if (this.mathInitialized != null) {
        return;
      }
      window._$_ = PaperScript._$_;
      window.$_ = PaperScript.$_;
      new ScalarMath(this.ops);
      new ArrayMath(this.ops, this.assignOps);
      new ComplexMath(this.basicOps);
      new NumericFunctions;
      new BlabPrinter;
      new BlabPlotter;
      new EvalBoxPlotter;
      return this.mathInitialized = true;
    };

    BlabCoffee.prototype.compile = function(code, bare) {
      var codeLines, firstLine, js, lf, vanilla;
      if (bare == null) {
        bare = false;
      }
      lf = "\n";
      codeLines = code.split(lf);
      firstLine = codeLines[0];
      vanilla = firstLine === "#!vanilla";
      if (!vanilla) {
        this.initializeMath();
        codeLines = this.predefinedCoffeeLines.concat(codeLines);
        code = codeLines.join(lf);
      }
      js = CoffeeScript.compile(code, {
        bare: bare
      });
      if (!vanilla) {
        js = PaperScript.compile(js);
      }
      return js;
    };

    return BlabCoffee;

  })();

  TypeMath = (function() {

    function TypeMath(proto) {
      this.proto = proto;
    }

    TypeMath.prototype.setMethod = function(op) {
      return this.proto[op] = function(y) {
        return numeric[op](this, y);
      };
    };

    TypeMath.prototype.setUnaryMethod = function(op) {
      return this.proto[op] = function() {
        return numeric[op](this);
      };
    };

    TypeMath.prototype.overloadOperator = function(a, b) {
      return this.proto["__" + b] = this.proto[a];
    };

    return TypeMath;

  })();

  ScalarMath = (function(_super) {

    __extends(ScalarMath, _super);

    function ScalarMath(ops) {
      var a, b, op, _i, _len, _ref;
      this.ops = ops;
      ScalarMath.__super__.constructor.call(this, Number.prototype);
      _ref = this.ops;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        op = _ref[_i];
        a = op[0], b = op[1];
        this.setMethod(a);
        this.overloadOperator(a, b);
      }
      this.proto.pow = function(p) {
        return Math.pow(this, p);
      };
    }

    ScalarMath.prototype.setMethod = function(op) {
      return this.proto[op] = function(y) {
        return numeric[op](+this, y);
      };
    };

    return ScalarMath;

  })(TypeMath);

  ArrayMath = (function(_super) {

    __extends(ArrayMath, _super);

    function ArrayMath(ops, assignOps) {
      var a, b, op, pow, _i, _j, _len, _len1, _ref, _ref1;
      this.ops = ops;
      this.assignOps = assignOps;
      ArrayMath.__super__.constructor.call(this, Array.prototype);
      this.proto.size = function() {
        return [this.length, this[0].length];
      };
      this.proto.max = function() {
        return Math.max.apply(null, this);
      };
      numeric.zeros = function(m, n) {
        return numeric.rep([m, n], 0);
      };
      numeric.ones = function(m, n) {
        return numeric.rep([m, n], 1);
      };
      _ref = this.ops;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        op = _ref[_i];
        a = op[0], b = op[1];
        this.setMethod(a);
        this.overloadOperator(a, b);
      }
      _ref1 = this.assignOps;
      for (_j = 0, _len1 = _ref1.length; _j < _len1; _j++) {
        op = _ref1[_j];
        this.setMethod(op);
      }
      this.setMethod("dot");
      this.setUnaryMethod("neg");
      this.overloadOperator("neg", "negate");
      this.setUnaryMethod("clone");
      this.setUnaryMethod("sum");
      this.proto.transpose = function() {
        return numeric.transpose(this);
      };
      Object.defineProperty(this.proto, 'T', {
        get: function() {
          return this.transpose();
        }
      });
      pow = numeric.pow;
      this.proto.pow = function(p) {
        return pow(this, p);
      };
      numeric.rand = function(sz) {
        if (sz == null) {
          sz = null;
        }
        if (sz) {
          return numeric.random(sz);
        } else {
          return Math.random();
        }
      };
    }

    return ArrayMath;

  })(TypeMath);

  ComplexMath = (function(_super) {

    __extends(ComplexMath, _super);

    function ComplexMath(ops) {
      var complex, j, j2, negj, op, _i, _len, _ref;
      this.ops = ops;
      ComplexMath.__super__.constructor.call(this, numeric.T.prototype);
      numeric.complex = function(x, y) {
        if (y == null) {
          y = 0;
        }
        return new numeric.T(x, y);
      };
      complex = numeric.complex;
      this.proto.size = function() {
        return [this.x.length, this.x[0].length];
      };
      _ref = this.ops;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        op = _ref[_i];
        this.defineOperators(op[0], op[1]);
      }
      this.proto.__negate = this.proto.neg;
      Object.defineProperty(this.proto, 'T', {
        get: function() {
          return this.transpose();
        }
      });
      Object.defineProperty(this.proto, 'H', {
        get: function() {
          return this.transjugate();
        }
      });
      this.proto.arg = function() {
        var x, y;
        x = this.x;
        y = this.y;
        return numeric.atan2(y, x);
      };
      this.proto.pow = function(p) {
        var a, nm, pa, r;
        nm = numeric;
        r = this.abs().x;
        a = this.arg();
        pa = a.mul(p);
        return complex(nm.cos(pa), nm.sin(pa)).mul(r.pow(p));
      };
      this.proto.sqrt = function() {
        return this.pow(0.5);
      };
      this.proto.log = function() {
        var a, r;
        r = this.abs().x;
        a = this.arg();
        return complex(numeric.log(r), a);
      };
      j = complex(0, 1);
      j2 = complex(0, 2);
      negj = complex(0, -1);
      this.proto.sin = function() {
        var e1, e2;
        e1 = (this.mul(j)).exp();
        e2 = (this.mul(negj)).exp();
        return (e1.sub(e2)).div(j2);
      };
      this.proto.cos = function() {
        var e1, e2;
        e1 = (this.mul(j)).exp();
        e2 = (this.mul(negj)).exp();
        return (e1.add(e2)).div(2);
      };
    }

    ComplexMath.prototype.defineOperators = function(op, op1) {
      var numericOld;
      numericOld = {};
      this.proto["__" + op1] = this.proto[op];
      numericOld[op] = numeric[op];
      return numeric[op] = function(x, y) {
        if (typeof x === "number" && y instanceof numeric.T) {
          return numeric.complex(x)[op](y);
        } else {
          return numericOld[op](x, y);
        }
      };
    };

    return ComplexMath;

  })(TypeMath);

  NumericFunctions = (function() {

    NumericFunctions.prototype.overrideFcns = ["sqrt", "sin", "cos", "exp", "log"];

    function NumericFunctions() {
      var f, nabs, natan2, nm, npow, _i, _len, _ref;
      _ref = this.overrideFcns;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        f = _ref[_i];
        this.override(f);
      }
      nm = numeric;
      npow = nm.pow;
      nm.pow = function(x, p) {
        if (x.pow != null) {
          return x.pow(p);
        } else {
          return npow(x, p);
        }
      };
      nabs = nm.abs;
      nm.abs = function(x) {
        if ((x.abs != null) && x instanceof nm.T) {
          return x.abs().x;
        } else {
          return nabs(x);
        }
      };
      natan2 = nm.atan2;
      nm.atan2 = function(y, x) {
        if (typeof x === "number" && typeof y === "number") {
          return Math.atan2(y, x);
        } else {
          return natan2(y, x);
        }
      };
    }

    NumericFunctions.prototype.override = function(name) {
      var f;
      f = numeric[name];
      return numeric[name] = function(x) {
        if (typeof x === "object" && (x[name] != null)) {
          return x[name]();
        } else {
          return f(x);
        }
      };
    };

    return NumericFunctions;

  })();

  BlabPrinter = (function() {

    function BlabPrinter() {
      var id, nm;
      nm = numeric;
      id = "blab_print";
      nm.print = function(x) {
        var container, htmlOut;
        container = $("#" + id);
        if (!container.length) {
          container = $("<div>", {
            id: id
          });
          htmlOut = $("#codeout_html");
          htmlOut.append(container);
        }
        return container.append("<pre>" + nm.prettyPrint(x) + "</pre>");
      };
      nm.print.clear = function() {
        var container;
        container = $("#" + id);
        if (container) {
          return container.empty();
        }
      };
    }

    return BlabPrinter;

  })();

  BlabPlotter = (function() {

    function BlabPlotter() {
      numeric.htmlplot = function(x, y, params) {
        var flot, htmlOut, _ref;
        if (params == null) {
          params = {};
        }
        flot = $("#flot");
        if (!flot.length) {
          flot = $("<div>", {
            id: "flot",
            css: {
              width: "600px",
              height: "300px"
            }
          });
          htmlOut = $("#codeout_html");
          htmlOut.append(flot);
        }
        if ((_ref = params.series) == null) {
          params.series = {
            color: "#55f"
          };
        }
        return $.plot($("#flot"), [numeric.transpose([x, y])], params);
      };
    }

    return BlabPlotter;

  })();

  EvalBoxPlotter = (function() {

    function EvalBoxPlotter() {
      var _this = this;
      this.container = $("#result_container");
      this.container.css({
        position: "absolute"
      });
      this.clear();
      numeric.plot = function(x, y, params) {
        if (params == null) {
          params = {};
        }
        return _this.plot(x, y, params);
      };
      numeric.plot.clear = function() {
        return _this.clear();
      };
      numeric.figure = function(params) {
        if (params == null) {
          params = {};
        }
        return _this.figure(params);
      };
      numeric.plotSeries = function(series, params) {
        if (params == null) {
          params = {};
        }
        return _this.plotSeries(series, params);
      };
      this.figures = [];
    }

    EvalBoxPlotter.prototype.clear = function() {
      this.plotCount = 0;
      return $(".eval_flot").remove();
    };

    EvalBoxPlotter.prototype.figure = function(params) {
      var flotId;
      if (params == null) {
        params = {};
      }
      flotId = "eval_plot_" + this.plotCount;
      this.figures[flotId] = new Figure(this.container, flotId, params);
      this.plotCount++;
      return flotId;
    };

    EvalBoxPlotter.prototype.plot = function(x, y, params) {
      var fig, flotId, _ref;
      if (params == null) {
        params = {};
      }
      flotId = (_ref = params.fig) != null ? _ref : this.figure(params);
      fig = this.figures[flotId];
      fig.plot(x, y);
      if (params.fig) {
        return null;
      } else {
        return flotId;
      }
    };

    EvalBoxPlotter.prototype.plotSeries = function(series, params) {
      var fig, flotId, _ref;
      if (params == null) {
        params = {};
      }
      flotId = (_ref = params.fig) != null ? _ref : this.figure(params);
      fig = this.figures[flotId];
      fig.plotSeries(series);
      if (params.fig) {
        return null;
      } else {
        return flotId;
      }
    };

    return EvalBoxPlotter;

  })();

  Figure = (function() {

    function Figure(container, flotId, params) {
      var _ref, _ref1,
        _this = this;
      this.container = container;
      this.flotId = flotId;
      this.params = params;
      this.w = this.container[0].offsetWidth;
      this.flot = $("<div>", {
        id: this.flotId,
        "class": "eval_flot",
        css: {
          position: "absolute",
          top: "0px",
          width: ((_ref = this.params.width) != null ? _ref : this.w - 50) + "px",
          height: ((_ref1 = this.params.height) != null ? _ref1 : 150) + "px",
          margin: "0px",
          marginLeft: "30px",
          marginTop: "20px",
          zIndex: 1
        }
      });
      this.container.append(this.flot);
      this.flot.hide();
      this.positioned = false;
      setTimeout((function() {
        return _this.setPos();
      }), 10);
    }

    Figure.prototype.setPos = function() {
      var e, idx, p, _i, _len, _ref, _ref1;
      p = null;
      _ref = $blab.evaluator;
      for (idx = _i = 0, _len = _ref.length; _i < _len; idx = ++_i) {
        e = _ref[idx];
        if ((typeof e === "string") && e === this.flotId) {
          p = idx;
        }
      }
      if (!p) {
        return;
      }
      this.flot.css({
        top: "" + (p * 22) + "px"
      });
      this.flot.show();
      if ((_ref1 = this.axesLabels) != null) {
        _ref1.position();
      }
      return this.positioned = true;
    };

    Figure.prototype.plot = function(x, y) {
      var d, line, nLines, v, _base, _i, _len, _ref;
      if ((_ref = (_base = this.params).series) == null) {
        _base.series = {
          color: "#55f"
        };
      }
      if ((y != null ? y.length : void 0) && (y[0].length != null)) {
        nLines = y.length;
        d = [];
        for (_i = 0, _len = y.length; _i < _len; _i++) {
          line = y[_i];
          v = numeric.transpose([x, line]);
          d.push(v);
        }
      } else {
        d = [numeric.transpose([x, y])];
      }
      if (!this.positioned) {
        this.flot.show();
      }
      $.plot(this.flot, d, this.params);
      if (!this.positioned) {
        this.flot.hide();
      }
      this.axesLabels = new AxesLabels(this.flot, this.params);
      if (this.positioned) {
        return this.axesLabels.position();
      }
    };

    Figure.prototype.plotSeries = function(series) {
      var _base, _ref;
      if ((_ref = (_base = this.params).series) == null) {
        _base.series = {
          color: "#55f"
        };
      }
      if (!this.positioned) {
        this.flot.show();
      }
      $.plot(this.flot, series, this.params);
      if (!this.positioned) {
        this.flot.hide();
      }
      this.axesLabels = new AxesLabels(this.flot, this.params);
      if (this.positioned) {
        return this.axesLabels.position();
      }
    };

    return Figure;

  })();

  AxesLabels = (function() {

    function AxesLabels(container, params) {
      this.container = container;
      this.params = params;
      if (this.params.xlabel) {
        this.xaxisLabel = this.appendLabel(this.params.xlabel, "xaxisLabel");
      }
      if (this.params.ylabel) {
        this.yaxisLabel = this.appendLabel(this.params.ylabel, "yaxisLabel");
      }
    }

    AxesLabels.prototype.appendLabel = function(txt, className) {
      var label;
      label = $("<div>", {
        text: txt
      });
      label.addClass("axisLabel");
      label.addClass(className);
      this.container.append(label);
      return label;
    };

    AxesLabels.prototype.position = function() {
      var _ref, _ref1;
      if ((_ref = this.xaxisLabel) != null) {
        _ref.css({
          marginLeft: (-this.xaxisLabel.width() / 2 + 10) + "px",
          marginBottom: "-20px"
        });
      }
      return (_ref1 = this.yaxisLabel) != null ? _ref1.css({
        marginLeft: "-27px",
        marginTop: (this.yaxisLabel.width() / 2 - 10) + "px"
      }) : void 0;
    };

    return AxesLabels;

  })();

  /* Not used - to obsolete
  
  complexMatrices: ->
  	
  	Array.prototype.complexParts = ->
  		A = this
  		[m, n] = size A
  		vParts = (v) -> [(a.x for a in v), (a.y for a in v)]
  		if not n
  			# Vector
  			[real, imag] = vParts A
  		else
  			# Matrix
  			real = new Array m
  			imag = new Array m
  			[real[m], imag[m]] = vParts(row) for row, m in A
  		[real, imag]
  	
  	# These could be made more efficient.
  	Array.prototype.real = -> this.complexParts()[0]
  	Array.prototype.imag = -> this.complexParts()[1]
  	
  	#Array.prototype.isComplex = ->
  	#	A = this
  	#	[m, n] = size A
  
  manualOverloadExamples: ->
  	# Not currently used - using numericjs instead.
  	
  	Number.prototype.__add = (y) ->
  		# ZZZ is this inefficient for scaler x+y?
  		if typeof y is "number"
  			return this + y
  		else if y instanceof Array
  			return (this + yn for yn in y)
  		else
  			undefined
  
  	Array.prototype.__add = (y) ->
  		if typeof y is "number"
  			return (x + y for x in this)
  		else if y instanceof Array
  			return (x + y[n] for x, n in this)
  		else
  			undefined
  */


  window.$pz = {};

  window.$blab = {};

  MathJaxProcessor = (function() {

    MathJaxProcessor.prototype.source = "http://cdn.mathjax.org/mathjax/latest/MathJax.js?config=default";

    MathJaxProcessor.prototype.mode = "HTML-CSS";

    function MathJaxProcessor() {
      var configScript, mathjax,
        _this = this;
      this.outputId = "blab_container";
      $blab.mathjaxConfig = function() {
        $.event.trigger("mathjaxPreConfig");
        window.MathJax.Hub.Config({
          jax: ["input/TeX", "output/" + _this.mode],
          tex2jax: {
            inlineMath: [["$", "$"], ["\\(", "\\)"]]
          },
          TeX: {
            equationNumbers: {
              autoNumber: "AMS"
            }
          },
          elements: [_this.outputId, "blab_refs"],
          showProcessingMessages: false,
          MathMenu: {
            showRenderer: true
          }
        });
        return window.MathJax.HTML.Cookie.Set("menu", {
          renderer: _this.mode
        });
      };
      configScript = $("<script>", {
        type: "text/x-mathjax-config",
        text: "$blab.mathjaxConfig();"
      });
      mathjax = $("<script>", {
        type: "text/javascript",
        src: this.source
      });
      $("head").append(configScript).append(mathjax);
      $(document).on("htmlOutputUpdated", function() {
        return _this.process();
      });
    }

    MathJaxProcessor.prototype.process = function() {
      var Hub, configElements, queue,
        _this = this;
      if (typeof MathJax === "undefined" || MathJax === null) {
        return;
      }
      this.id = this.outputId;
      Hub = MathJax.Hub;
      queue = function(x) {
        return Hub.Queue(x);
      };
      queue(["PreProcess", Hub, this.id]);
      queue(["Process", Hub, this.id]);
      configElements = function() {
        return Hub.config.elements = [_this.id];
      };
      return queue(configElements);
    };

    return MathJaxProcessor;

  })();

  CoffeeEvaluator = (function() {

    CoffeeEvaluator.prototype.noEvalStrings = [")", "]", "}", "\"\"\"", "else", "try", "catch", "finally", "alert", "console.log"];

    CoffeeEvaluator.prototype.lf = "\n";

    CoffeeEvaluator.compile = function(code, bare) {
      var js, _ref;
      if (bare == null) {
        bare = false;
      }
      if ((_ref = CoffeeEvaluator.blabCoffee) == null) {
        CoffeeEvaluator.blabCoffee = new BlabCoffee;
      }
      return js = CoffeeEvaluator.blabCoffee.compile(code, bare);
    };

    CoffeeEvaluator["eval"] = function(code, js) {
      if (js == null) {
        js = null;
      }
      if (!js) {
        js = CoffeeEvaluator.compile(code);
      }
      eval(js);
      return js;
    };

    function CoffeeEvaluator() {
      this.js = null;
    }

    CoffeeEvaluator.prototype.process = function(code, recompile, stringify) {
      var codeLines, compile, e, js, l, n, result;
      if (recompile == null) {
        recompile = true;
      }
      if (stringify == null) {
        stringify = true;
      }
      compile = recompile || !(this.evalLines && this.js);
      if (compile) {
        codeLines = code.split(this.lf);
        $blab.evaluator = (function() {
          var _i, _len, _results;
          _results = [];
          for (_i = 0, _len = codeLines.length; _i < _len; _i++) {
            l = codeLines[_i];
            _results.push(this.isComment(l) && stringify ? l : "");
          }
          return _results;
        }).call(this);
        this.evalLines = ((function() {
          var _i, _len, _results;
          _results = [];
          for (n = _i = 0, _len = codeLines.length; _i < _len; n = ++_i) {
            l = codeLines[n];
            _results.push((this.noEval(l) ? "" : "$blab.evaluator[" + n + "] = ") + l);
          }
          return _results;
        }).call(this)).join(this.lf);
        js = null;
      } else {
        js = this.js;
      }
      try {
        this.js = CoffeeEvaluator["eval"](this.evalLines, js);
      } catch (error) {
        console.log("eval error", error);
      }
      if (!stringify) {
        return $blab.evaluator;
      }
      return result = (function() {
        var _i, _len, _ref, _results;
        _ref = $blab.evaluator;
        _results = [];
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          e = _ref[_i];
          _results.push(e === "" ? "" : (e && e.length && e[0] === "#" ? e : this.objEval(e)));
        }
        return _results;
      }).call(this);
    };

    CoffeeEvaluator.prototype.noEval = function(l) {
      var r, _i, _len, _ref;
      if ((l === null) || (l === "") || (l.length === 0) || (l[0] === " ") || (l[0] === "#") || (l.indexOf("#;") !== -1)) {
        return true;
      }
      _ref = this.noEvalStrings;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        r = _ref[_i];
        if (l.indexOf(r) === 0) {
          return true;
        }
      }
      return false;
    };

    CoffeeEvaluator.prototype.isComment = function(l) {
      return l.length && l[0] === "#" && (l.length < 3 || l.slice(0, 3) !== "###");
    };

    CoffeeEvaluator.prototype.objEval = function(e) {
      var finish1, line;
      try {
        line = $inspect2(e, {
          depth: 2
        });
        finish1 = new Date().getTime() / 1000;
        line = line.replace(/(\r\n|\n|\r)/gm, "");
        return line;
      } catch (error) {
        return "";
      }
    };

    return CoffeeEvaluator;

  })();

  window.CoffeeEvaluator = CoffeeEvaluator;

  getBlabId = function() {
    var blab, h, p, query;
    query = location.search.slice(1);
    if (!query) {
      return null;
    }
    h = query.split("&");
    p = h != null ? h[0].split("=") : void 0;
    return blab = p.length && p[0] === "blab" ? p[1] : null;
  };

  loadMainCss = function(blab) {
    var css;
    css = $("<link>", {
      rel: "stylesheet",
      type: "text/css",
      href: "main.css"
    });
    return $(document.head).append(css);
  };

  loadMainHtml = function(blab, callback) {
    return $.get("/" + blab + "/main.html", function(data) {
      return callback(data);
    });
  };

  loadExtrasJs = function(blab) {
    var js;
    js = $("<script>", {
      src: "/" + blab + "/extras.js"
    });
    return $(document.head).append(js);
  };

  loadMainJs = function(blab) {
    var $js, head, js;
    head = document.getElementsByTagName('head')[0];
    $js = $("<script>", {
      type: "text/javascript",
      src: "main.js"
    });
    js = $js[0];
    head.appendChild(js);
    return;
    js = $("<script>", {
      src: "main.js"
    });
    return $(document.head).append(js);
  };

  getFileDivs = function(blab) {};

  getBlab = function() {
    var blab;
    blab = getBlabId();
    if (!blab) {
      return null;
    }
    return loadMainHtml(blab, function(data) {
      loadExtrasJs(blab);
      loadMainJs(blab);
      return githubForkRibbon(blab);
    });
  };

  htmlNode = function() {
    var html;
    html = "<div id=\"code_nodes\" data-module-id=\"\">\n<div class=\"code_node_container\" id=\"code_node_container_html\" data-node-id=\"html\" data-filename=\"main.html\">\n	<div class=\"code_node_output_container\" id=\"output_html\">\n		<div class=\"code_node_html_output\" id=\"codeout_html\"></div>\n	</div>\n</div>\n</div>";
    return $("#blab_container").append(html);
  };

  githubForkRibbon = function(blab) {
    var html;
    html = "<a href=\"https://github.com/puzlet/" + blab + "\" id=\"ribbon\" style=\"opacity:0.2\"><img style=\"position: absolute; top: 0; right: 0; border: 0;\" src=\"https://camo.githubusercontent.com/365986a132ccd6a44c23a9169022c0b5c890c387/68747470733a2f2f73332e616d617a6f6e6177732e636f6d2f6769746875622f726962626f6e732f666f726b6d655f72696768745f7265645f6161303030302e706e67\" alt=\"Fork me on GitHub\" data-canonical-src=\"https://s3.amazonaws.com/github/ribbons/forkme_right_red_aa0000.png\"></a>";
    $("#blab_container").append(html);
    return setTimeout(function() {
      return $("#ribbon").fadeTo(400, 1).fadeTo(400, 0.2);
    }, 2000);
  };

  init0 = function() {
    var blab;
    blab = getBlabId();
    if (!blab) {
      return;
    }
    Array.prototype.dot = function(y) {
      return numeric.dot(+this, y);
    };
    htmlNode();
    loadMainCss(blab);
    console.log("time0", Date.now());
    return loadMainHtml(blab, function(data) {
      $("#codeout_html").append(Wiky.toHtml(data));
      new MathJaxProcessor;
      return init(function() {
        loadMainJs(blab);
        return githubForkRibbon(blab);
      });
    });
  };

  init = function(callback) {
    var head, js;
    js = $("<script>", {
      type: "text/javascript",
      src: "http://puzlet.com/puzlet/php/source.php?pageId=b00bj&file=d3.min.js"
    });
    js[0].onload = function() {
      console.log("js loaded");
      return callback();
    };
    head = document.getElementsByTagName('head')[0];
    return head.appendChild(js[0]);
  };

  initNew = function() {
    var blab;
    blab = "cs-intro";
    if (!blab) {
      return;
    }
    Array.prototype.dot = function(y) {
      return numeric.dot(+this, y);
    };
    htmlNode();
    loadMainCss(blab);
    console.log("time0", Date.now());
    new MathJaxProcessor;
    return init(function() {
      loadMainJs(blab);
      return githubForkRibbon(blab);
    });
  };

  OLDloadJS = function(url) {
    var $js, head, js;
    head = document.getElementsByTagName('head')[0];
    $js = $("<script>", {
      type: "text/javascript",
      src: "main.js"
    });
    js = $js[0];
    head.appendChild(js);
    return;
    js = $("<script>", {
      src: "main.js"
    });
    return $(document.head).append(js);
  };

  Resources = (function() {

    function Resources(spec) {
      this.spec = spec;
      this.head = document.getElementsByTagName('head')[0];
      this.load();
    }

    Resources.prototype.load = function() {
      var resource, resources, url, _i, _len;
      this.resourcesToLoad = 0;
      resources = this.spec.resources;
      if (!resources) {
        this.spec.loaded();
        return;
      }
      this.wait = false;
      for (_i = 0, _len = resources.length; _i < _len; _i++) {
        resource = resources[_i];
        url = resource.url;
        if (url.indexOf(".js") !== -1) {
          this.addScript(resource);
        } else if (url.indexOf(".css") !== -1) {
          this.addCss(resource);
        } else {

        }
      }
      if (!this.wait && this.resourcesToLoad === 0) {
        return this.spec.loaded();
      }
    };

    Resources.prototype.addScript = function(resource) {
      var js, url,
        _this = this;
      if (window[resource["var"]]) {
        console.log("Already loaded", resource);
        return;
      }
      url = resource.url;
      this.wait = true;
      this.resourcesToLoad++;
      js = document.createElement("script");
      js.setAttribute("src", url);
      js.setAttribute("type", "text/javascript");
      js.setAttribute("class", this.spec.resourcesClass);
      js.onload = function() {
        return _this.resourceLoaded(resource);
      };
      return document.head.appendChild(js);
    };

    Resources.prototype.addCss = function(resource) {
      var css, url,
        _this = this;
      url = resource.url;
      this.wait = true;
      this.resourcesToLoad++;
      css = document.createElement("link");
      css.setAttribute("href", url);
      css.setAttribute("rel", "stylesheet");
      css.setAttribute("type", "text/css");
      css.setAttribute("class", this.spec.resourcesClass);
      css.onload = function() {
        return _this.resourceLoaded(resource);
      };
      return document.head.appendChild(css);
    };

    Resources.prototype.resourceLoaded = function(resource) {
      console.log("Loaded", resource);
      this.resourcesToLoad--;
      if (this.resourcesToLoad === 0) {
        return this.spec.loaded();
      }
    };

    Resources.prototype.removeAll = function(resourcesClass) {
      var resources;
      resources = $("." + resourcesClass);
      if (resources.length) {
        return resources.remove();
      }
    };

    return Resources;

  })();

  loadJS = function(url, callback) {
    var js;
    js = document.createElement("script");
    js.setAttribute("src", url);
    js.setAttribute("type", "text/javascript");
    js.onload = function() {
      return callback();
    };
    return document.head.appendChild(js);
  };

  loadJQuery = function(callback) {
    if (typeof jQuery !== "undefined" && jQuery !== null) {
      return callback();
    } else {
      return loadJS("http://code.jquery.com/jquery-1.8.3.min.js", function() {
        return callback();
      });
    }
  };

  init1 = function() {
    var blab, load1, loadExtras, loadPage;
    blab = window.location.pathname.split("/")[1];
    load1 = function(callback) {
      var spec;
      spec = {
        resources: [
          {
            url: "http://code.jquery.com/jquery-1.8.3.min.js",
            "var": "jQuery"
          }, {
            url: "/puzlet/css/coffeelab.css"
          }, {
            url: "/puzlet/js/wiky.js",
            "var": "Wiky"
          }, {
            url: "/" + blab + "/main.css"
          }
        ],
        resourcesClass: "core_resources",
        loaded: function() {
          return callback();
        }
      };
      return new Resources(spec);
    };
    loadExtras = function(callback) {
      var spec;
      spec = {
        resources: [
          {
            url: "http://puzlet.com/puzlet/php/source.php?pageId=b00bj&file=d3.min.js",
            "var": "d3"
          }, {
            url: "/puzlet/js/numeric-1.2.6.js",
            "var": "numeric"
          }, {
            url: "/puzlet/js/jquery.flot.min.js"
          }
        ],
        resourcesClass: "extra_resources",
        loaded: function() {
          return callback();
        }
      };
      return new Resources(spec);
    };
    loadPage = function(callback) {
      return $.get("/" + blab + "/main.html", function(data) {
        var container;
        Array.prototype.dot = function(y) {
          return numeric.dot(+this, y);
        };
        container = $("<div>", {
          id: "blab_container"
        });
        $(document.body).append(container);
        htmlNode();
        $("#codeout_html").append(Wiky.toHtml(data));
        new MathJaxProcessor;
        return loadExtras(function() {
          loadMainJs(blab);
          githubForkRibbon(blab);
          return callback();
        });
      });
    };
    return load1(function() {
      console.log("Resources loaded");
      return loadPage(function() {
        return console.log("Page loaded");
      });
    });
  };

  init1();

}).call(this);
