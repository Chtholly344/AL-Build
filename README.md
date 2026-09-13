<div align="center">
  <img src="https://count.getloli.com/@azurlanejmbq?name=azurlanejmbq&theme=moebooru&padding=7&offset=0&align=top&scale=1&pixelated=1&darkmode=auto" alt="访问计数" />
  <h3 align="center">AL Build</h3>

  ![forks](https://img.shields.io/github/forks/Chtholly344/AL-Build.svg?style=flat&label=Forks)
  ![stars](https://img.shields.io/github/stars/Chtholly344/AL-Build?style=flat&label=Stars)
  ![issues](https://img.shields.io/github/issues/Chtholly344/AL-Build?label=Issues)
  
  <p align="center">
    使用 Github Workflow 一键构建对应区服的 APK/XAPK 安装包
    <br />
    <br />
    <a>发现问题？提交</a>
    <a href="https://github.com/Chtholly344/AL-Build/issues">Issue</a>
  </p>
</div>

---

## 免责声明
！本项目仅供学习、研究与交流之用。请在遵守当地相关法律法规的前提下使用。

**使用者在下载、运行或获取本项目相关内容后，请务必在 24 小时内将其从计算机或存储介质中完全删除。**

使用者因违反法律法规、未按提示删除或违反本声明规定，从而触犯法律或造成任何直接/间接损失的，其后果均由使用者本人自行承担，本项目开发者/维护者不承担任何明示或暗示的法律责任。一旦开始使用或下载本项目，即视为您已完全知晓并同意本声明的所有条款。

---

## 风险及注意事项
- **账号风险**：使用本项目（及相关修改后的应用程序）可能涉及不可预测的潜在风险。若您选择继续使用，须自行承担由此引发的一切后果，包括但不限于账号被限制登录、功能封禁或永久注销。
- **签名&登录**：由于重新打包后的应用程序签名与官方原版不一致，可能导致第三方快捷授权登录失效。遇到此类情况，请优先采用二维码扫码或手机验证码的方式进行登录。

---

## 项目目录
```

├── 📁 .github
│    └── 📁 workflows
│         ├── ⚙️ main.yml  # APK 构建流
│         ├── ⚙️ xapk.yml  # XAPK 构建流
│         └── ⚙️ generate-release.yml  # 标签触发，多区服矩阵构建并发布 Release
├── 📁 assets
│    ├── 📁 images  # 图片
│    ├── 📁 key  # 签名文件
│    │    ├── 📄 testkey.pk8
│    │    └── 📄 testkey.x509.pem
│    └── 📄 merge_build.sh  # 构建脚本 
├── 📝 comfig.json.example  # 区服配置示例（配合 generate-release.yml）
└── 📝 README.md

```

---

## 已知且不会解决的问题
- **KR服**：启动无响应，可能触发反作弊机制。
- **HW服**：启动界面卡顿，已确认是由于 HMS Core 的签名验证问题导致。

---

## 相关仓库
1. ~~[JMBQ/azurlane](https://github.com/JMBQ/azurlane) (被封禁)~~
2. [JMBQ01/azurlan](https://github.com/JMBQ01/azurlan)
2. [n0k0m3/PerseusCI](https://github.com/n0k0m3/PerseusCI)

---

## Star历史
[![Star History Chart](https://api.star-history.com/svg?repos=Chtholly344/AL-Build&type=Date)](https://star-history.com/#Chtholly344/AL-Build&Date)