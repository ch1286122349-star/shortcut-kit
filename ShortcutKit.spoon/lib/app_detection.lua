local Detection = {}

function Detection.find(applications, candidates)
  for _, bundleID in ipairs(candidates or {}) do
    local app = applications.get(bundleID)
    if app then return app, bundleID end
    if applications.pathForBundleID and applications.pathForBundleID(bundleID) then
      return nil, bundleID
    end
  end
  return nil, nil
end

return Detection
