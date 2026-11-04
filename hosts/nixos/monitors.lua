-- Reference desk only. Match EDID descriptions rather than dock connector numbers.
hl.monitor({ output = "desc:BOE NV140WUM-N4H", mode = "preferred", position = "-1920x120", scale = 1 })
hl.monitor({ output = "desc:Beihai Century Joint Innovation Technology Co.Ltd P2510S 0000000000000",
    mode = "2560x1440@120", position = "0x0", scale = 1 })
hl.monitor({ output = "desc:Acer Technologies KG251Q T8ZAA0048563",
    mode = "1920x1080@119.98", position = "320x-1080", scale = 1, transform = 2 })

return {
    ["BOE NV140WUM-N4H"] = 0,
    ["Beihai Century Joint Innovation Technology Co.Ltd P2510S 0000000000000"] = 1,
    ["Acer Technologies KG251Q T8ZAA0048563"] = 2,
}
