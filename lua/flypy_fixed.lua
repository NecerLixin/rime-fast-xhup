local F = {}

function F.init(env)
    local config = env.engine.schema.config
    env.schema_id = config:get_string("schema/schema_id")
    env.reversedb = ReverseLookup(env.schema_id)
    env.top_mark = config:get_string("pin_word/comment_mark") or "🔝"
    env.custom_mark = config:get_string("custom_phrase/comment_mark") or " 📌"
end

function F.func(input, env)
    local seglen = 0
    local drop_cand = false
    local context = env.engine.context
    local composition = context.composition

    if composition:empty() then return end
    local segment = composition:back()
    seglen = segment and segment.length
    local preedit_code = context.input
    local _, symbol_count = preedit_code:gsub("[`']", "")
    local syllable_len = (seglen > 1) and math.ceil(seglen / 2) or (#preedit_code - symbol_count)

    for cand in input:iter() do
        local cand_text = cand.text:gsub(" ", "")
        local cand_text_len = utf8.len(cand_text)
        local cand_dtype = cand:get_dynamic_type()

        if cand.comment:match("^" .. env.top_mark .. "$") then
            yield(cand)                                     -- 带有 top_mark 标记的候选词条, 优先显示
        elseif cand_text:match("<br>") then
            local ccand_text = cand_text:gsub("<br>", "\n") -- 词条有<br>标签, 将其转为换行符
            yield(cand:to_shadow_candidate(cand.type, ccand_text, env.custom_mark))
        elseif                                              -- 丢弃一些候选结果 去掉候选注解包含`太极️☯ ` 的候选项
            string.find(cand.comment, "☯")
            or (                                            -- 开头大写的输入编码, 去掉只有单字母的候选
                preedit_code:match("^[%u][%a]+")
                and cand_text:match("^[A-Z]$")
            ) or ( -- 辅码筛字时, 过滤掉 emoji
                preedit_code:match("^%l+[`/][%l`/]+$")
                and (cand_dtype == "Shadow")
            ) or ( -- 辅码模式下, 过滤掉长度超出音节长度的候选
                preedit_code:match("^%l+[`/][%l`/]+$")
                and (cand_text_len > syllable_len)
            ) or ( -- V模式下, 过滤掉中英混合词条
                preedit_code:match("^V%a+$") and
                cand_text:find("([\228-\233][\128-\191]-)")
            ) or ( -- 候选词长度超出音节长度 1 个以上的候选
                (cand.type == "completion") and
                (cand_text_len - syllable_len > 1) and
                cand_text:find("([\228-\233][\128-\191]-)")
            ) or (
                (cand_text_len - syllable_len > 2) and
                cand_text:find("([\228-\233][\128-\191]-)")
            )
        then
            drop_cand = true
        else
            yield(cand)
        end
    end

    if drop_cand then drop_cand = false end
end

return F
