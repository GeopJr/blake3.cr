{% if !file_exists?("#{__DIR__}/../blake3c/libblake3.a") && env("BLAKE3_CR_DO_NOT_BUILD") != "1" %}
  {{ run("#{__DIR__}/compile_blake3").nil? }}
{% end %}

require "./digest/blake3"
