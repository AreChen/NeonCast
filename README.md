# NeonCast

NeonCast 是為《魔獸世界》永恆服製作的玩家施法條插件，以 Kefer 的 ChromaCast 為基礎，保留其 MIT 授權（見 LICENSE）。

## 安裝與使用

把插件檔案放入 `Interface/AddOns/NeonCast`，停用 ChromaCast 以免施法條重複。輸入 `/neoncast` 或 `/nc` 開啟設置，拖曳施法條即可調整位置。設置與位置依角色保存。

可以調整條的尺寸、文字、引導刻度、法術佇列、延遲顯示、主題強調色與施法條顏色。介面根據客戶端語言提供繁體中文、簡體中文和英文，部分提示文字暫為英文。

批量製作計數監聽 `C_TradeSkillUI.CraftRecipe`，只有當客戶端提供有效數量，且配方 ID 與施法 ID 一致時才顯示進度，不會猜測未知數量。永恆服的實際 API 行為仍需在遊戲中驗證。

## 測試

使用 Python 安裝 `lupa` 與 `pytest`，然後執行 `python -m pytest tests`。這些測試不代替遊戲內測試。
