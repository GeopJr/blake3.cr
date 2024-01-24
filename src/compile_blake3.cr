arch_defaults = {
  sse2:   {{ env("BLAKE3_NO_SSE2") != "1" }},
  sse41:  {{ env("BLAKE3_NO_SSE41") != "1" }},
  avx2:   {{ env("BLAKE3_NO_AVX2") != "1" }},
  avx512: {{ env("BLAKE3_NO_AVX512") != "1" }},
  neon:   {{ env("BLAKE3_NO_NEON") == "0" || env("BLAKE3_USE_NEON") == "1" || nil }},
}

{% if env("BLAKE3_CR_OVERRIDE_DEFAULTS") != "1" %}
    {% if flag?(:aarch64) %}
        arch_defaults = {
            sse2: false,
            sse41: false,
            avx2: false,
            avx512: false,
            neon: true
        }
    {% end %}
{% end %}

cc = {{ env("CC") || "cc" }}
cflags = {{ env("CFLAGS") || "-O3 -Wall -Wextra -std=c11 -pedantic -fstack-protector-strong -D_FORTIFY_SOURCE=2 -fPIE -fvisibility=hidden" }}
ldflags = {{ env("LDFLAGS") || "-pie -Wl,-z,relro,-z,now" }}
targets = [] of String
asm_targets = [] of String
extraflags = ["-Wa,--noexecstack"]
base_targets = {"blake3", "blake3_dispatch", "blake3_portable"}
additional_flags = {
  blake3_sse2:   "-msse2",
  blake3_sse41:  "-msse4.1",
  blake3_avx2:   "-mavx2",
  blake3_avx512: "-mavx512f -mavx512vl",
}

unless arch_defaults[:sse2]
  extraflags << "-DBLAKE3_NO_SSE2"
else
  targets << "blake3_sse2"
  asm_targets << "blake3_sse2_x86-64_unix.S"
end

unless arch_defaults[:sse41]
  extraflags << "-DBLAKE3_NO_SSE41"
else
  targets << "blake3_sse41"
  asm_targets << "blake3_sse41_x86-64_unix.S"
end

unless arch_defaults[:avx2]
  extraflags << "-DBLAKE3_NO_AVX2"
else
  targets << "blake3_avx2"
  asm_targets << "blake3_avx2_x86-64_unix.S"
end

unless arch_defaults[:avx512]
  extraflags << "-DBLAKE3_NO_AVX512"
else
  targets << "blake3_avx512"
  asm_targets << "blake3_avx512_x86-64_unix.S"
end

# can be nil (default)
if arch_defaults[:neon] == true
  extraflags << "-DBLAKE3_USE_NEON=1"
  targets << "blake3_neon"
end

if arch_defaults[:neon] == false
  extraflags << "-DBLAKE3_USE_NEON=0"
end

commands = [] of String

base_targets.each do |target|
  commands << "#{cc} #{cflags} -c -o #{target}.o #{target}.c"
end

targets.each do |target|
  commands << "#{cc} #{cflags} #{extraflags.join(" ")} -c #{target}.c -o #{target}.o #{additional_flags[target]?}"
end

commands << "ar rcs libblake3.a #{base_targets.map { |x| "#{x}.o" }.join(" ")} #{targets.map { |x| "#{x}.o" }.join(" ")} #{asm_targets.join(" ")}"

commands.each do |command|
  `cd #{__DIR__}/../blake3c && #{command}`
end
