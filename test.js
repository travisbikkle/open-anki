"use strict";
(function () {
  var kFzX = 'rralucard' + Math.random(),
    shouldShuffle = false;

  function shuffle(t) {
    for (var r, n = []; t.length > 0;)
      r = Math.floor(Math.random() * t.length), n.push(t[r]), t.splice(r, 1);
    return n;
  }

  function equal(t, r) {
    if (t.length !== r.length) return !1;
    for (var n = 0; n < t.length; n++)
      if (!r.includes(t[n])) return;
  }

  function getLi(t, r, n) {
    var i = document.createElement("li"),
      o = document.createElement("input"),
      a = document.createElement("label");
    o.setAttribute("type", 1 === gData.correctanswer.length ? "radio" : "checkbox");
    o.setAttribute("name", "ckname");
    o.setAttribute("id", "ckid" + n);
    o.setAttribute("value", r);
    a.setAttribute("for", "ckid" + n);
    i.appendChild(o);
    t = t.trim();
    t = t.replace(/^[A-Fa-f]\. 0*/, "");
    a.innerHTML = t;
    i.appendChild(a);
    i.setAttribute("onclick", "choice(this)");
    i.setAttribute("id", "option" + n);
    return i;
  }

  function choice(t) {
    gData.clickNum++;
    var r = t.id.substr(-1);
    if (gData.correctanswer.length > 1) {
      gData.options[r].isChecked = document.getElementById("ckid" + r).checked;
    } else {
      for (var n = 0; n < gData.options.length; n++)
        document.getElementById("ckid" + n).checked
          ? (gData.options[n].isChecked = !0)
          : (gData.options[n].isChecked = !1);
    }
  }

  var optionList = document.getElementById("optionList"),
    classify = document.getElementById("classify"),
    options = document.getElementById("options"),
    answer = document.getElementById("answer"),
    correctanswer = answer.innerText.toUpperCase().match(/[A-Fa-f]/g);

  correctanswer.length > 1 && (classify.innerText = "多选题：");

  options = options.innerHTML;
  options = options.replace(/<\/?div>/g, "\n");
  options = options.replace(/\n+/g, "\n");
  options = options.replace(/<br.*?>/g, "\n");
  options = options.replace(/^\n/, "");
  options = options.replace(/\n$/, "");
  options = options.split(/(\n|\r\n)/g).filter(function (t) {
    return "\n" !== t && "\r\n" !== t && "" !== t;
  }) || [];

  for (var optionsArray = [], i = 0; i < options.length; i++)
    correctanswer.indexOf(String.fromCharCode(i + 65)) > -1
      ? optionsArray.push({ text: options[i], isChecked: !1, value: !0 })
      : optionsArray.push({ text: options[i], isChecked: !1, value: !1 });

  shouldShuffle && (optionsArray = shuffle(optionsArray));
  gData.options = optionsArray;

  for (var tempLi = [], tepmAnswer = [], i = 0; i < optionsArray.length; i++)
    optionsArray[i].value && tepmAnswer.push(String.fromCharCode(i + 65));
  gData.correctanswer = tepmAnswer;

  for (var i = 0; i < optionsArray.length; i++)
    tempLi.push(getLi(optionsArray[i].text, optionsArray[i].value, i));
  tempLi.forEach(function (t) {
    optionList.appendChild(t);
  });
  gData.list = optionList.innerHTML;

  var iZhCycUPfEnkWo = "rralucard:" + Math.random();
  function UbmqFMmIXK() {
    var Tqrrz = 'rralucard' + Math.random();
    return Tqrrz;
  }
  var RzUWZ = UbmqFMmIXK();
})();