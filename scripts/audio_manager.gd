extends Node

# 音效节点名称与用途映射
var sfx_nodes = {
    "shoot": "SFX_Shoot",
    "explosion": "SFX_Explosion",
    "button": "SFX_Button",
    "hit": "SFX_Hit",
    "upgrade": "SFX_Upgrade",
    "coin": "SFX_Coin",
    "levelup": "SFX_LevelUp",
    "gameover": "SFX_GameOver"
}

func play_sfx(name: String):
    if sfx_nodes.has(name):
        var node = get_node_or_null(sfx_nodes[name])
        if node:
            node.play()
        else:
            print("[AudioManager] Node not found for:", name)
    else:
        print("[AudioManager] SFX name not mapped:", name)
