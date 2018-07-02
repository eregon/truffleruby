def trap(sig, prc=nil, &block)
  if sig == "INFO" or sig == :INFO
    # Ignore
  else
    super
  end
end
