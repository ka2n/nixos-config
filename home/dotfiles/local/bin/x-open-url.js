// vim:set ft=javascript

const path = require('path');
const os = require('os');
const cp = require('child_process');
const fs = require('fs');

const main = () => {
  const config = loadConfig();
  const argv = process.argv.slice(2);
  for (const url of argv) {
    open(config, url);
  }
}

function open(config, url) {
  let cmd = config.browser;
  if (!config.match_all.test(url.toString())) {
    spawnDetached(cmd, [url]);
    return
  };

  const rule = config.rules.find(r => r.pattern.test(url));
  url = rule.modify(url);
  cmd = rule.cmd ?? config.browser
  spawnDetached(cmd, [url]);
}

function spawnDetached(cmd, args) {
  cp.spawn(cmd, args, { detached: true, stdio: 'ignore' });
}

function loadConfig() {
  const configDir = path.resolve(
    process.env.XDG_CONFIG_HOME || path.join(os.homedir(), ".config"),
    "x-open-url"
  );

  // 一般的な設定を読み込み (必須)
  const generalConfigPath = path.join(configDir, "config.json");
  const generalConfig = require(generalConfigPath);

  // 個人的な設定を読み込み
  const privateConfigPath = path.join(configDir, "config.private.json");
  const privateConfig = fs.existsSync(privateConfigPath)
    ? require(privateConfigPath)
    : {};

  // マージ（private が優先）
  const merged = {
    browser: privateConfig.browser ?? generalConfig.browser,
    rules: [
      ...(generalConfig.rules || []),
      ...(privateConfig.rules || [])
    ]
  };

  const rules = merged.rules.map(rule => {
    return {
      ...rule,
      pattern: new RegExp(rule.pattern),
      modify: transformModifyConfig(rule.mods),
    }
  });

  return {
    match_all: new RegExp(rules.map(r => r.pattern.source).join("|")),
    rules,
    browser: merged.browser,
  };
}

function transformModifyConfig(modifications) {
  return (input) => {
    if (!(modifications && modifications.length > 0)) return input;
    return modifications.reduce((v, { action, data }) => {
      switch (action) {
        case "url_replace": {
          return v.replace(new RegExp(data[0]), data[1]);
        }
        case "prepend": {
          return data + v;
        }
        case "append": {
          return v + data;
        }
        case "uri_encode": {
          return encodeURIComponent(v);
        }
      }
      return v
    }, input);
  }
}

main()
