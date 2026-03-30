-- liu_related_filter.lua
-- 依 LikeIME related 表重新排序下一詞候選，補上 liur 的聯想詞行為。
-- 這個 filter 不改動主字典，只在有上一個上屏詞時提升相關候選排序。

local M = {}

local data_cache = {
    loaded = false,
    map = {},
    base_map = {},
    learned_map = {},
}

local runtime_state = {
    pending_selection = nil,
}

local function ensure_bucket(map, key)
    local bucket = map[key]
    if not bucket then
        bucket = {}
        map[key] = bucket
    end
    return bucket
end

local function safe_trim(text)
    if not text then
        return ""
    end
    return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function unescape_field(text)
    return (
        text
        :gsub("\\t", "\t")
        :gsub("\\r", "\r")
        :gsub("\\n", "\n")
        :gsub("\\\\", "\\")
    )
end

local function escape_related_field(text)
    return (
        text
        :gsub("\\", "\\\\")
        :gsub("\t", "\\t")
        :gsub("\r", "\\r")
        :gsub("\n", "\\n")
    )
end

local function split_tsv_line(line)
    local pword, cword, score = line:match("^([^\t]+)\t([^\t]+)\t(-?%d+)$")
    if not pword or not cword or not score then
        return nil
    end
    return unescape_field(pword), unescape_field(cword), tonumber(score)
end

local function build_data_path(env)
    local configured = env.engine.schema.config:get_string(env.name_space .. "/data")
    local file_name = configured ~= "" and configured or "likeime_related.tsv"
    local learned_name = env.engine.schema.config:get_string(env.name_space .. "/learned_data")
    if learned_name == "" then
        learned_name = "likeime_related.user.tsv"
    end
    return {
        user_path = rime_api.get_user_data_dir() .. "/" .. file_name,
        shared_path = rime_api.get_shared_data_dir() .. "/" .. file_name,
        learned_path = rime_api.get_user_data_dir() .. "/" .. learned_name,
    }
end

local function load_related_lines(path, related_map)
    local fh = io.open(path, "r")
    if not fh then
        return false
    end

    for line in fh:lines() do
        if line ~= ""
            and line ~= "# LikeIME related export for Rime liur"
            and line ~= "# pword\\tcword\\tscore"
            and line ~= "# LikeIME related runtime learning for Rime liur"
        then
            local pword, cword, score = split_tsv_line(line)
            if pword and cword then
                local bucket = ensure_bucket(related_map, pword)
                bucket[cword] = (bucket[cword] or 0) + score
            end
        end
    end
    fh:close()
    return true
end

local function load_related_data(env)
    local paths = build_data_path(env)
    local related_map = {}
    local base_map = {}
    local learned_map = {}
    local loaded_any = false

    if load_related_lines(paths.user_path, related_map) then
        load_related_lines(paths.user_path, base_map)
        loaded_any = true
    elseif load_related_lines(paths.shared_path, related_map) then
        load_related_lines(paths.shared_path, base_map)
        loaded_any = true
    end
    if load_related_lines(paths.learned_path, related_map) then
        load_related_lines(paths.learned_path, learned_map)
        loaded_any = true
    end

    if not loaded_any then
        log.warning("liu_related_filter: related data file not found.")
    end

    data_cache.loaded = true
    data_cache.map = related_map
    data_cache.base_map = base_map
    data_cache.learned_map = learned_map
    data_cache.learned_path = paths.learned_path
end

local function get_fallback_key(text)
    local last_char = nil
    for _, code in utf8.codes(text or "") do
        local char = utf8.char(code)
        if char:match("%S") then
            last_char = char
        end
    end
    return last_char or ""
end

local function append_learned_pair(path, pword, cword, score)
    local fh = io.open(path, "a")
    if not fh then
        return false
    end

    fh:write(
        escape_related_field(pword),
        "\t",
        escape_related_field(cword),
        "\t",
        tostring(score),
        "\n"
    )
    fh:close()
    return true
end

local function learn_pair(env, pword, cword)
    if not pword or not cword or pword == "" or cword == "" or pword == cword then
        return
    end

    local bucket = ensure_bucket(data_cache.map, pword)
    local learned_bucket = ensure_bucket(data_cache.learned_map, pword)
    local delta = env.learning_delta or 40

    local pending = runtime_state.pending_selection
    if pending and pending.text == cword and pending.rank and pending.rank >= 2 and pending.rank <= 4 then
        delta = delta + (env.explicit_learning_bonus or 120)
    end

    bucket[cword] = (bucket[cword] or 0) + delta
    learned_bucket[cword] = (learned_bucket[cword] or 0) + delta

    if data_cache.learned_path then
        local file_exists = io.open(data_cache.learned_path, "r")
        if file_exists then
            file_exists:close()
        else
            local init_fh = io.open(data_cache.learned_path, "w")
            if init_fh then
                init_fh:write("# LikeIME related runtime learning for Rime liur\n")
                init_fh:write("# pword\\tcword\\tscore\n")
                init_fh:close()
            end
        end
        append_learned_pair(data_cache.learned_path, pword, cword, delta)
    end

    runtime_state.pending_selection = nil
end

local function get_latest_committed_text(env)
    if env.last_committed_text and env.last_committed_text ~= "" then
        return env.last_committed_text
    end

    local context = env.engine.context
    if context.commit_history and not context.commit_history:empty() then
        local latest = context.commit_history:latest_text()
        if latest and latest ~= "" then
            return latest
        end
    end

    return ""
end

local function sanitize_comment(comment)
    if not comment or comment == "" then
        return ""
    end

    local cleaned = comment
        :gsub("%s*[〔［%[]聯想[〕］%]]", "")
        :gsub("%s*聯想", "")
        :gsub("^%s+", "")
        :gsub("%s+$", "")

    return cleaned
end

local function sanitize_candidate(cand)
    local comment = sanitize_comment(cand.comment or "")
    if comment == (cand.comment or "") then
        return cand
    end

    return cand:to_shadow_candidate(cand.type, cand.text, comment)
end

local function mark_learned_candidate(cand, marker)
    if not marker or marker == "" then
        return cand
    end

    local comment = sanitize_comment(cand.comment or "")
    if comment:find(marker, 1, true) then
        return cand
    end

    local new_comment = comment == "" and marker or (comment .. " " .. marker)
    return cand:to_shadow_candidate(cand.type, cand.text, new_comment)
end

local function get_candidate_quality(cand)
    return cand.quality or 0
end

local function should_bypass(context)
    local input_text = context.input or ""
    if input_text == "" then
        return true
    end

    local first_char = input_text:sub(1, 1)
    if first_char == ";" or first_char == "`" or first_char == "'" or first_char == "," then
        return true
    end

    if context:get_option("ascii_mode") then
        return true
    end

    return false
end

local function init_common_config(env)
    env.last_committed_text = ""
    env.previous_committed_text = ""
    env.max_promoted = env.engine.schema.config:get_int(env.name_space .. "/max_promoted")
    if not env.max_promoted or env.max_promoted <= 0 then
        env.max_promoted = 8
    end
    env.learning_delta = env.engine.schema.config:get_int(env.name_space .. "/learning_delta")
    if not env.learning_delta or env.learning_delta <= 0 then
        env.learning_delta = 40
    end
    env.explicit_learning_bonus = env.engine.schema.config:get_int(env.name_space .. "/explicit_learning_bonus")
    if not env.explicit_learning_bonus or env.explicit_learning_bonus <= 0 then
        env.explicit_learning_bonus = 120
    end
    env.learned_debug_marker = env.engine.schema.config:get_string(env.name_space .. "/learned_debug_marker")
    if env.learned_debug_marker == "" then
        env.learned_debug_marker = "〔學習〕"
    end
end

function M.init(env)
    init_common_config(env)

    env.commit_notifier = env.engine.context.commit_notifier:connect(function(ctx)
        local committed_text = safe_trim(ctx:get_commit_text())
        if env.last_committed_text ~= "" and committed_text ~= "" then
            learn_pair(env, env.last_committed_text, committed_text)

            local previous_fallback = get_fallback_key(env.last_committed_text)
            local current_fallback = get_fallback_key(committed_text)
            if previous_fallback ~= "" and current_fallback ~= "" then
                learn_pair(env, previous_fallback, current_fallback)
            end
        end
        env.previous_committed_text = env.last_committed_text
        env.last_committed_text = committed_text
        runtime_state.pending_selection = nil
    end)

    if not data_cache.loaded then
        load_related_data(env)
    end
end

function M.processor_init(env)
    init_common_config(env)
end

function M.processor(key, env)
    local context = env.engine.context
    local composition = context.composition
    if not composition or composition:empty() then
        return 2
    end

    local seg = composition:back()
    if not seg or not seg.menu or seg.menu:candidate_count() <= 0 then
        return 2
    end

    local key_repr = key:repr()
    local selected_index = nil

    if key_repr == "space" or key_repr == "Return" or key_repr == "KP_Enter" then
        selected_index = seg.selected_index
    else
        local digit = key_repr:match("^[1-9]$")
        if not digit then
            digit = key_repr:match("^KP_([1-9])$")
        end
        if digit then
            local page_size = env.engine.schema.page_size or 5
            selected_index = math.floor(seg.selected_index / page_size) * page_size + tonumber(digit) - 1
        end
    end

    if selected_index and selected_index >= 0 and selected_index < seg.menu:candidate_count() then
        local cand = seg.menu:get_candidate_at(selected_index)
        if cand and cand.text and cand.text ~= "" then
            runtime_state.pending_selection = {
                rank = selected_index + 1,
                text = cand.text,
            }
        end
    end

    return 2
end

function M.fini(env)
    if env.commit_notifier then
        env.commit_notifier:disconnect()
        env.commit_notifier = nil
    end
end

function M.func(input, env)
    local context = env.engine.context

    local function yield_sanitized_all()
        for cand in input:iter() do
            yield(sanitize_candidate(cand))
        end
    end

    if should_bypass(context) then
        yield_sanitized_all()
        return
    end

    local previous_text = safe_trim(get_latest_committed_text(env))
    if previous_text == "" then
        yield_sanitized_all()
        return
    end

    local related_bucket = data_cache.map[previous_text]
    if not related_bucket then
        local fallback_key = get_fallback_key(previous_text)
        if fallback_key ~= "" then
            related_bucket = data_cache.map[fallback_key]
        end
    end
    if not related_bucket then
        yield_sanitized_all()
        return
    end

    local promoted = {}
    local ordinary = {}
    local learned_bucket = data_cache.learned_map[previous_text]
    if not learned_bucket then
        local fallback_key = get_fallback_key(previous_text)
        if fallback_key ~= "" then
            learned_bucket = data_cache.learned_map[fallback_key]
        end
    end
    for cand in input:iter() do
        cand = sanitize_candidate(cand)
        local score = related_bucket[cand.text]
        if score then
            local is_learned = learned_bucket and learned_bucket[cand.text]
            if is_learned then
                cand = mark_learned_candidate(cand, env.learned_debug_marker)
            end
            promoted[#promoted + 1] = {
                candidate = cand,
                score = score,
                learned = is_learned and learned_bucket[cand.text] or 0,
            }
        else
            ordinary[#ordinary + 1] = cand
        end
    end

    table.sort(promoted, function(a, b)
        if a.score == b.score then
            if a.learned ~= b.learned then
                return a.learned > b.learned
            end
            local a_quality = get_candidate_quality(a.candidate)
            local b_quality = get_candidate_quality(b.candidate)
            if a_quality == b_quality then
                return a.candidate.text < b.candidate.text
            end
            return a_quality > b_quality
        end
        return a.score > b.score
    end)

    local promoted_count = math.min(#promoted, env.max_promoted)
    for idx = 1, promoted_count do
        yield(promoted[idx].candidate)
    end

    for idx = promoted_count + 1, #promoted do
        ordinary[#ordinary + 1] = promoted[idx].candidate
    end

    for _, cand in ipairs(ordinary) do
        yield(cand)
    end
end

return {
    liu_related_filter = {
        init = M.init,
        func = M.func,
        fini = M.fini,
    },
    liu_related_processor = {
        init = M.processor_init,
        func = M.processor,
        fini = M.fini,
    },
}
