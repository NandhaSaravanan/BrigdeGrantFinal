import { Link } from 'react-router-dom'

export function NotFoundPage() {
  return (
    <div className="state">
      <h1>Page not found</h1>
      <p>The page you are looking for does not exist.</p>
      <Link className="btn btn-primary" to="/">
        Go to home
      </Link>
    </div>
  )
}
