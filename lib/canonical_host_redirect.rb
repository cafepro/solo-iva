class CanonicalHostRedirect
  MOVED_PERMANENTLY = 301

  def initialize(app, canonical_host:, canonical_scheme: "https")
    @app = app
    @canonical_host = canonical_host
    @canonical_scheme = canonical_scheme
    @redirect_host = "www.#{canonical_host}"
  end

  def call(env)
    request = ActionDispatch::Request.new(env)
    return @app.call(env) unless redirect?(request.host)

    [
      MOVED_PERMANENTLY,
      {
        "Location" => "#{@canonical_scheme}://#{@canonical_host}#{request.fullpath}",
        "Content-Type" => "text/plain",
        "Content-Length" => "0"
      },
      []
    ]
  end

  private

  def redirect?(host)
    host.casecmp?(@redirect_host)
  end
end
